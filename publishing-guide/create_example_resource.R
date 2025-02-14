library(tidyverse)
library(palmerpenguins)

glimpse(penguins)

penguins_transformed <- penguins |> 
  mutate(across(everything(), as.character)) |> 
  mutate(across(c(ends_with('_mm'), ends_with('_g'), year), 
                ~replace_na(.x, "NaN")))

glimpse(penguins_transformed)

write_csv(penguins_transformed, 
          'example_resource.csv')
