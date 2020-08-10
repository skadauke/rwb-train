FROM rstudio/rstudio-server-pro:latest

# Set default environment variables -------------------------------------------#

ENV N_USERS 200
ENV USER_PREFIX train
ENV RSP_LAUNCHER false 

# Install additional system packages ------------------------------------------#

RUN apt-get update --fix-missing && apt-get install -y --no-install-recommends \
        libxml2-dev \
        vim \
        git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
    
# Install R packages ----------------------------------------------------------#

RUN R -e 'install.packages("devtools", repos="https://packagemanager.rstudio.com/cran/__linux__/bionic/latest")' && \
    R -e 'install.packages("tidyverse", repos="https://packagemanager.rstudio.com/cran/__linux__/bionic/latest")' && \
    R -e 'install.packages("shiny", repos="https://packagemanager.rstudio.com/cran/__linux__/bionic/latest")' && \
    R -e 'install.packages("flexdashboard", repos="https://packagemanager.rstudio.com/cran/__linux__/bionic/latest")' && \
    R -e 'install.packages("rmarkdown", repos="https://packagemanager.rstudio.com/cran/__linux__/bionic/latest")'

COPY start_rsp_train.sh /usr/local/bin/start_rsp_train.sh
RUN chmod +x /usr/local/bin/start_rsp_train.sh
COPY create_users_table.R /usr/local/bin/create_users_table.R
RUN chmod +x /usr/local/bin/create_users_table.R

CMD ["start_rsp_train.sh", "$N_USERS", "$PW_SEED", "$USER_PREFIX"]
