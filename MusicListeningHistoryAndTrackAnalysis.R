#This is the script to pull a user's last.fm music scrobble (entire listening history), and then search each track using song title and artist name in spotify's database, to return a reverse chronological list of songs with corresponding detailed music analysis data. 
#Written by Drew Walker
# INSTALL/LOAD PACKAGES ---------------------------------------------------
install.packages("tidyverse")
install.packages("devtools")
devtools::install_github('charlie86/spotifyr')
devtools::install_github("condwanaland/scrobbler")
install.packages("purrr")
install.packages("Rcpp")
install.packages("knitr")
install.packages("lubridate")
#Experimenting with parallel computing and timing
install.packages("furrr")
install.packages("tictoc")
#Added Library installation of package "Rcpp" due to error code in work computer-- may not need if we install Rtools first
#if installing for first time, this "checkpoint" package helps us load and install the other necessary packages 
library(tidyverse)
library(devtools)
library(spotifyr)
library(scrobbler)
library(purrr)
library(dplyr)
library(Rcpp)
library(knitr)
library(lubridate)
library(furrr)
library(tictoc)
# VERSION CONTROL ---------------------------------------------------------
#Initiate packrat snapshot for version control 
packrat::status()
packrat::snapshot()
# Spotify Search Function -----------------------------------------
track_audio_features <- function(artist, title, type = "track") {
  search_results <- search_spotify(paste(artist, title), type = type)
  track_audio_feats <- get_track_audio_features(search_results$id[[1]])
  return(track_audio_feats)
}

# create a version of this function which can handle errors
possible_af <- possibly(track_audio_features, otherwise = tibble())
# scrobbler and spotify API. username = "last.fm username"---------------------------------------------------------------
my_data <- scrobbler::download_scrobbles(username = "thedrewwalker", api_key = "50d7685d484772f2ff42c45891b31c7b")
#This sets up system env variables that grant our app authorization to pull GET requests from Spotify API
Sys.setenv(SPOTIFY_CLIENT_ID = '2c46a5d6764f425ab746a56a1c8791b9')
Sys.setenv(SPOTIFY_CLIENT_SECRET = '9b809cd5be004e8fbbc72ad74b0e19a7')
access_token <- get_spotify_access_token(client_id = Sys.getenv("SPOTIFY_CLIENT_ID"), 
                                         client_secret = Sys.getenv("SPOTIFY_CLIENT_SECRET"))
#This begins the authorization process, linked to the account most recently signed in
colnames(my_data)
colnames(my_data)[colnames(my_data)=="song_title"] <- "title"
##Now, we'll make a function that applys the search track audio features through the rows of artists and track titles.
# Mapping search function -------------------------------------------------
tic()
future::plan(multiprocess)
possible_feats <- possibly(track_audio_features, otherwise = tibble("NA"))
totalaudio_features <- my_data %>%
  mutate(audio_features = future_map2(artist, title, possible_feats)) %>%
  unnest() %>% 
  as_tibble()
toc()
#The following code will create one huge .csv file
#Now we will change the dates given by last.fm to UTC timestamps. It's worth noting we are only accurate to the minute
totalaudio_features$date <- dmy_hm(totalaudio_features$date)
#Now we'll convert to change to US Timezone for easier data analysis
totalaudio_features$date <- with_tz(totalaudio_features$date, tzone = "US/Eastern")
#Then we make a title element that updates with the timestamp of the data pull. MAKE SURE YOU CHANGE USER HERE

# CHANGE USER FOR FILENAMING ------------------------------------------------
csvFileName <- paste("drewmusic",format(Sys.time(),"%d-%b-%Y %H.%M"),".csv")
#and we make the csv that will be saved in the working directory 
write.csv(totalaudio_features, file = csvFileName)
#©Copyright September 12th, 2019, University of Florida Research Foundation, Inc. All Rights Reserved.
