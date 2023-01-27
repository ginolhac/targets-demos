library(targets)
library(tarchetypes)
library(tibble) # for the values object

# load the tidyverse quietly for each target
# which each runs in a fresh R session
tar_option_set(packages = "tidyverse")

# Static branching with dynamic branching inside
values <- tibble(
  folders = c("lines", "circles", "others")
)

# tar_map() generates R expressions, and substitute the desired 'values'
mapped <- tar_map(
  values = values,
  names = "folders", # to avoid targets reporting "files_lines_lines"
  tar_target(files, fs::dir_ls(folders, glob = "*tsv")),
  # Dynamic within static
  tar_target(ds, read_tsv(files, show_col_types = FALSE),
             pattern = map(files)),
  tar_target(summary_stat, summarise(ds, m_x = mean(x), m_y = mean(y)),
             pattern = map(ds)),
  tar_target(plots, ggplot(ds, aes(x, y)) +
               geom_point(),
             pattern = map(ds),
             iteration = "list"),
  # Patchwork each group into one plot
  tar_target(patch_plots, 
             wrap_plots(plots) + 
               # Title the last bit of path_plots_{cicles,lines,others}
               plot_annotation(title = stringr::str_split_i(tar_name(), '_', -1)),
             packages = "patchwork")
)

# We want to combined in one tibble the 3 tibble of summary stats
# Each of one them is actually composed of 2, 4 and 7 tibbles
stat_combined <- tar_combine(
  stat_summaries,
  mapped[[3]], # Unfortunately, we need indices to tell which target to act on
  # And a bit of metaprogramming, using triple bang (!!!) for force evaluation
  command = dplyr::bind_rows(!!!.x, .id = "ds_type")
)
# And the plots now
plot_combined <- tar_combine(
  plots_agg,
  mapped[[5]],
  command = wrap_plots(list(!!!.x), ncol = 2) + plot_annotation(title = "Master Saurus"),
  packages = "patchwork"
)

list(mapped, stat_combined, plot_combined, tar_render(report, "ds3.Rmd"))


# Sys.setenv(TAR_PROJECT = "ds_static")
# targets::tar_make()