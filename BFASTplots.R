## BFAST MAPS
library(bfast)
library(terra)
library(gtools)
library(sf)

setwd("~/BSU/MRRMAid/lab/quantChange/")

## import .tif as raster
ras = rast('Yankee.tif')
plot(ras)
crs(ras)

## import .shp for restoration AOI
shp = st_read('yankee.shp')

## insert an entire month of NAs for July 2019
july19 = rast(ras[[1]], vals = NA, names = c('1_1_040029_201907_mesic'))
july19

## add this empty rast to the full stack
ras = c(ras, july19)
ras

## add time stamps to each
names = names(ras)
dates = sapply(names, function(name){
  as.Date(paste0(unlist(strsplit(name, "_"))[4],"01"),"%Y%m%d")
})

## sort by dates
dates.sort = order(dates)
dates.sorted = as.Date(dates[dates.sort])
ras.sort = ras[[dates.sort]]

## apply the sorted dates to the 'time' property of the raster
terra::time(ras.sort)= dates.sorted

## double check times
time(ras.sort)

## Function to apply the bfast function and return outputs of interest
xbfast <- function(data) {  
  mesic <- ts(data, frequency=4, start=2004) 
  result <- bfast(mesic, season="harmonic", decomp = 'stlplus')#, max.iter=2, breaks=1)
  niter <- length(result$output)
  out <- result$output[[niter]]
  bp <- out$Wt.bp #breakpoint of the seasonality component
  st <- out$St #the seasonality component
  st_a <- st[1:bp] #seasonality until the breakpoint 
  st_b <- st[bp:64] #hard coded end-point 
  st_amin <- min(st_a)
  st_amax <- max(st_a)
  st_bmin <- min(st_b)
  st_bmax <- max(st_b)
  st_adif <- st_amax - st_amin
  st_bdif <- st_bmax - st_bmin
  st_dif <- st_bdif - st_adif
  Magni<-result$Magnitude #magnitude of the biggest change detected in the trend component
  Timing<-result$Time #timing of the biggest change detected in the trend component
  return(c(st_dif,bp,Magni,Timing)) 
}

## apply bfast to every pixel using app()
bfast.output <- app(ras.sort, fun=xbfast)
## plot all outputs
plot(bfast.output)

## a 4 panel plot
parameter <- par(mfrow = c(1,4))
## sep 2004
parameter <- plot(ras.sort[[4]], main = "Panel A\nMesic vegetation\n proportion Sep 2004", range = c(0, 0.6))
plot(st_geometry(shp), border = "red", add = T, lwd = 2)
## sep 2020
parameter <- plot(ras.sort[[64]], main = "Panel B\nMesic vegetation\n proportion Sep 2020", range = c(0, 0.6))
plot(st_geometry(shp), border = "red", add = T, lwd = 2)
## Individual BFAST outputs
diff <- subset(bfast.output, 1)
time <- subset(bfast.output, 2)
magn <- subset(bfast.output, 3)
magn.time <- subset(bfast.output, 4)

## Magnitude change
parameter <- plot(magn, main = "Panel C\nLargest magnitude\n of change in trend")
plot(st_geometry(shp), border = "red", add = T, lwd = 2)
## substitute dates for indices
years.vect = c(rep(2004,4), rep(2005,4), rep(2006,4), rep(2007,4), rep(2008,4),rep(2009,4), rep(2010,4),rep(2011,4),
               rep(2012,4),rep(2013,4),rep(2014,4),rep(2015,4),rep(2017,4),rep(2018,4),rep(2019,4),rep(2020,4))
## Time of greatest magnitude change
magn.time.dates = subst(magn.time, from = c(1:64), to = years.vect)
parameter <- plot(magn.time.dates, main = "Panel D\nTime of largest magnitude\n of change in trend")
plot(st_geometry(shp), border = "red", add = T, lwd = 2)

############ Images reduced to a single value for comparison ###################

## read the data
data = read.csv('yankee.csv')

## BFAST can't handle missing values 
## Insert a row for July 2019
data[nrow(data) +1,] = c("July 1, 2019", NA)

## sort the df
data = data[order(as.Date(data$system.time_start, format = "%b %e, %Y")),]
rownames(data) = 1:nrow(data)

data$mesic = as.numeric(data$mesic)

## define a function to interpolate
replace_na_with_mean <- function(df) {
  for (i in 1:ncol(df)) {
    na_indices <- which(is.na(df[, i]))
    for (j in na_indices) {
      if (j == 1) {
        df[j, i] <- df[j + 1, i]
      } else if (j == nrow(df)) {
        df[j, i] <- df[j - 1, i]
      } else {
        df[j, i] <- mean(c(df[j - 1, i], df[j + 1, i]))
      }
    }
  }
  return(df)
}

## apply the interpolation function to fill NAs
data.fill = replace_na_with_mean(data)

## Embrace the NAs! insert some more for 2016
data.2016 = cbind(c("Jun 1, 2016", "July 1, 2016", "Aug 1, 2016", "Sep 1, 2016"),
                  c(rep(NA,4)))

colnames(data.2016) = c("system.time_start", "mesic")
data.NAs = rbind(data, data.2016)
data.NAs$date = as.Date(data.NAs$system.time_start, format = "%b %e, %Y")
data.NAs = data.NAs[order(data.NAs$date),]

## create a time series object
data.ts = ts(data.fill$mesic, frequency = 4)
data.ts.NA = ts(data.NAs$mesic, frequency = 4)

plot(data.ts, axes = F)
axis(1, at = 1:16, labels = years.bfast)
plot(data.ts.NA)

## apply the BFAST function
fit = bfast(data.ts, h = 0.15, season = "dummy")

years.bfast = c(2004, 2005, 2006, 2007, 2008, 2009, 2010,
                2011, 2012, 2013, 2014, 2015, 2017, 2018, 2019, 2020)

plot(fit, ANOVA = T, main = "BFAST output", xaxt = "n")
axis(1, at = 1:16, labels = years.bfast)
