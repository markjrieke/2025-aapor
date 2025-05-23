# setup ------------------------------------------------------------------------

# libraries
library(tidyverse)
library(ggdist)
library(ggblend)
library(riekelib)

pal <- c("#838cf1", "#f1838c", "#5a9282")

# true underlying population/group characteristics
groups <-
  tibble(group = LETTERS[1:4],
         group_mean = c(400, 800, 700, 600),
         population = c(0.6, 0.2, 0.1, 0.1),
         p_respond = c(0.1, 0.05, 0.03, 0.01)) %>%
  mutate(p_sampled = population * p_respond,
         p_sampled = p_sampled/sum(p_sampled))

# true mean among population
true_mean <-
  groups %>%
  summarise(true_mean = sum(group_mean * population)) %>%
  pull(true_mean)

# simulation parameters
n_sims <- 5000
sample_size <- 700
sigma <- 50

# plot! ------------------------------------------------------------------------

# setup simulation conditions
crossing(poll = 1:n_sims,
         differential_response = c(TRUE, FALSE),
         group_correlation = c(TRUE, FALSE),
         group = groups$group) %>%
  left_join(groups) %>%
  mutate(p_sampled = if_else(differential_response, p_sampled, population),
         group_mean = if_else(group_correlation, group_mean, true_mean)) %>%
  
  # simulate responses
  nest(data = -c(poll, differential_response, group_correlation)) %>%
  mutate(K = map(data, ~rmultinom(1, sample_size, .x$p_sampled)[,1])) %>%
  unnest(c(data, K)) %>%
  uncount(K) %>%
  bind_cols(Y = rnorm(nrow(.), .$group_mean, sigma)) %>%
  
  # summarize weighted/unweighted mean per simulation
  group_by(poll,
           group,
           differential_response,
           group_correlation) %>%
  mutate(n_group = n()) %>%
  group_by(poll,
           differential_response,
           group_correlation) %>%
  mutate(n_total = n(),
         observed = n_group/n_total,
         weight = population/observed) %>%
  summarise(weighted = sum(Y * weight)/sum(weight),
            unweighted = mean(Y)) %>%
  ungroup() %>%
  
  # prep for plotting
  pivot_longer(ends_with("weighted"),
               names_to = "method",
               values_to = "p") %>%
  mutate(case = case_when(differential_response & group_correlation ~ "Cell 4: Bias ↓ Variance ↓",
                          !differential_response & group_correlation ~ "Cell 3: Bias -- Variance ↓",
                          differential_response & !group_correlation ~ "Cell 2: Bias -- Variance ↑",
                          !differential_response & !group_correlation ~ "Cell 1: Bias -- Variance --")) %>%
  
  # plot!
  ggplot(aes(x = case,
             y = p,
             color = method,
             fill = method)) + 
  stat_histinterval(slab_alpha = 0.75) %>% partition(vars(method)) %>% blend("darken") +
  geom_hline(yintercept = true_mean,
             linetype = "dotted",
             color = "gray40") +
  scale_color_manual(values = rev(pal[1:2])) + 
  scale_fill_manual(values = rev(pal[1:2])) + 
  coord_flip() + 
  theme_rieke() + 
  theme(legend.position = "bottom") + 
  labs(title = "**Effect of weighting on estimates of the population mean**",
       subtitle = paste("Weighting on subgroups **decreases bias** and **decreases variance** when group",
                        "membership is highly correlated with response rate and preference in **continuous outcomes**",
                        sep = "<br>"),
       x = NULL,
       y = NULL,
       caption = paste("Distribution of weighted and unweighted population means for 5,000 simulated surveys",
                       "Dashed line indicates simulated true population mean",
                       sep = "<br>"))

  ggquicksave("img/continuous.png")



