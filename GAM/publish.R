library(RWordPress)
library(knitr)

options(WordpressLogin = c(mike = readLines("~/wp_login.txt")),
        WordpressURL = 'https://michael-barr.com/xmlrpc.php')

knit2wp('~/repos/modeling/gams_scams.Rmd', title = 'GAMs and scams: Part 1',
        categories = c("Data Science", "Insurance"),
        tags = c("r", "mgcv", "GAM", "scam", "modeling"),
        # action = "newPost",
        publish = FALSE)
