library(RWordPress)
library(knitr)

options(WordpressLogin = c(mike = readLines("~/wp_login.txt")),
        WordpressURL = 'https://michael-barr.com/xmlrpc.php')

knit2wp('~/repos/my_site/modeling/bayesianMBO/bayesianMBO.Rmd', title = 'Bayesian Model Based Optimization in R',
        categories = c("Data Science"),
        tags = c("R", "xgboost", "mlrMBO", "gaussian processes", "bayes", "workplace efficiency", "tweedie"),
        shortcode = c(TRUE,TRUE),
        # action = "newPost",
        action = "editPost",
        postid = 422,
        publish = TRUE)
