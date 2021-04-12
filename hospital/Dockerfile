FROM asachet/rocker-ml:latest

MAINTAINER Michael Barr "mike@michael-barr.com"

RUN R -e "install.packages(c( 'imputeTS', 'mgcv', 'bea.R', 'blsAPI', 'zoo', 'forecast', 'plumber'), repos='http://cran.rstudio.com/', dependencies = c('Depends', 'Imports'))"

# move files into container
COPY api/entrypoint.R /entrypoint.R
COPY api/plumber.R  /plumber.R
COPY api/deploy.RDS /deploy.RDS
COPY api/bea.csv /bea.csv
COPY api/bls.csv /bls.csv

# expose port within image 
EXPOSE 80

ENTRYPOINT ["Rscript", "main.R"]