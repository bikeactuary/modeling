# plumber.R

# set API title and description to show up in http://localhost:8000/__swagger__/
#* @apiTitle Forecast API
#* @apiDescription API for accessing forecasts from various model prediction services. PoC: only Hospital GET endpoint presently.

library(plumber)

#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg = "") {
  list(msg = paste0("The message is: '", msg, "'"))
}

# Environment

library(dplyr)
library(tidyr)
library(magrittr)
library(bea.R)
library(jsonlite)
library(blsAPI)
library(zoo)
library(forecast)
library(imputeTS)
library(mgcv)

# secret <- "a_super_secret_password_123"

# #* Log system time, request method and HTTP user agent of the incoming request
# #* @filter auth-logger
# function(req, res){
#
#   cat("System time:", as.character(Sys.time()), "\n",
#       "Request method:", req$REQUEST_METHOD, req$PATH_INFO, "\n",
#       "HTTP user agent:", req$HTTP_USER_AGENT, "@", req$REMOTE_ADDR, "\n" )
# 
#   if(is.null(req$HTTP_AUTHORIZATION)) {
#     res$status <- 401 # Unauthorized
#     return(list(error="Authentication is required"))
#   } else if (req$HTTP_AUTHORIZATION != secret) {
#     res$status <- 401 # Unauthorized
#     return(list(error="Authentication is invalid"))
#   } else if(req$HTTP_AUTHORIZATION == secret) {
#     plumber::forward()
#   }
# }

# load model stuff
stuff <- readRDS("deploy.RDS")

#* forecast generator
#* @param Year:int The years of the requested forecast periods
#* @param Month:int The months (as integer) of the requested forecast periods
#* @param bea_key:string A valid key for for the Bureau of Economic Analysis API
#* @param bls_key:string A valid key for for the Bureau of Labor Statistics API
#* @get /forecast
#* @serializer json
#* @response 200 Returns the forecast Hospital YoY% change for the requested periods
forecast <- function(Year, Month, bea_key, bls_key) {
  Year <- as.integer(Year); Month <- as.integer(Month);
  ## BEA Data
  bea_codes <- read.csv("bea.csv", header = FALSE) %>%
    pull(V1)
  
  beaSpecs <- list(
    'UserID' = bea_key ,
    'Method' = 'GetData',
    'DatasetName' = 'NIUnderlyingDetail',
    'TableName' = 'U20403',
    'Frequency' = 'M',
    'Year' = paste0(Year, collapse = ","),
    'ResultFormat' = 'json')
  
  dat.bea <- beaGet(beaSpecs) %>%
    filter(LineDescription %in% trimws(bea_codes)) %>%
    mutate(SeriesLine = paste0(SeriesCode, "_", LineNumber)) %>%
    select(-c(SeriesCode, LineNumber)) %>%
    relocate(SeriesLine, .after = TableName) %>%
    select(SeriesLine, LineDescription, 7:ncol(.)) %>%
    tidyr::gather(key = "period", value = "xit", -c(1:2)) %>%
    mutate(year = substr(period, 11, 14) %>% as.numeric,
           month = substr(period, 16, 17) %>% as.numeric) %>%
    select(-c(period, LineDescription)) %>%
    relocate(xit, .after = last_col()) %>%
    arrange(SeriesLine, year, month) %>%
    tidyr::pivot_wider(id_cols = c(SeriesLine, year, month),
                       names_from = SeriesLine,
                       values_from = xit)
  
  ## BLS Data
  
  bls_codes <- read.csv("bls.csv") %>% 
    pull(Series)
  
  for(i in 1:ceiling(length(bls_codes)/50)) {
    
    j <- min(i*50, length(bls_codes)) ## ending index of bls codes to submit in request i
    
    req <- list(
      'registrationkey'= bls_key,
      'seriesid'= bls_codes[((i-1)*50 + 1):j],
      'startyear'= min(Year),
      'endyear'= max(Year) )
    
    if(i == 1) {
      dat.bls <- blsAPI(req, api_version = 2, return_data_frame = TRUE)
    } else {
      dat.bls %<>% rbind(dat.bls, blsAPI(req, api_version = 2, return_data_frame = TRUE) )
    }
  }
  
  dat.bls %<>%
    group_by(seriesID, year, period, periodName) %>%
    summarise(value = first(value)) %>%
    ungroup() %>%
    mutate(year = year %>% as.integer,
           month = substr(period, 2, 3) %>% as.integer) %>%
    select(seriesID, year, month, value) %>%
    tidyr::pivot_wider(id_cols = c(seriesID, year, month),
                       names_from = seriesID,
                       values_from = value)
  
  ## Prep data
  
  ## hacked this here just to demo GET with single period
  
  #filter((year + month/12) %in% (Year + Month/12)
  x.ts <- ts(cbind(dat.bea %>% select(-c(year, month)),
                   dat.bls %>% select(-c(year, month))),
             frequency = 12,
             start = c(Year, 1) )
  
  x.ts <- x.ts[, stuff[[1]], drop = FALSE ] %>%
    na_locf(na_remaining = "mean")
  
  x.ts <- window(x.ts, start = c(Year, Month), end = c(Year, Month) ) ## for GET
  
  ## PCA transform
  
  X_pca <- predict(stuff[[2]], x.ts)
  
  ## GAM Predict
  
  gampreds <- predict(stuff[[3]], newdata = X_pca %>% as_tibble, type = "response") %>% as.vector() ## another hack for GET
  
  return(gampreds)
}
