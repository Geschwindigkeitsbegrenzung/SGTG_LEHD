getwd()
setwd("C:/lehd_data_ca")

lehd_links <- scan("C:/lehd_data_ca/lehd_links_ca_2013_only.csv", what = character())

# http://tutorials.iq.harvard.edu/R/RProgramming/Rprogramming.html
for(i in lehd_links) {
        download.file(i, 
                      destfile = basename(i),
                      method = "internal")
}

dateDownloaded <- date()
dateDownloaded