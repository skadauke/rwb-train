# RStudio Server Pro Training Environment

Docker image for an Intro to R training environment using RStudio Server Pro. This image is based on [rstudio/rstudio-server-pro](https://hub.docker.com/r/rstudio/rstudio-server-pro). It automatically generates a configurable number (up to 999) of training accounts, which can be useful for Intro to R courses such as [Intro to R for Clinicians](https://github.com/skadauke/intro-to-r-for-clinicians-rmed2020) at the [R/Medicine 2020 Virtual Conference](https://www.r-medicine.com).

## Features

The `Dockerfile` extends [rstudio/rstudio-server-pro](https://hub.docker.com/r/rstudio/rstudio-server-pro) by adding:

- The `libxml2-dev`, `vim`, and `git` packages
- The `tidyverse`, `rmarkdown`, and `devtools` R packages

In addition, the startup script accomplishes the following:

- Clones a GitHub repository with course materials.
  - Repos must contain two folders labeled `exercises` and `solutions`.
  - For an example repo, see <https://github.com/skadauke/intro-to-r-for-clinicians-rmed2020>.
- Creates a configurable number of users with a configurable prefix, e.g. `train001`, `train002`, ... or `rmed001`, `rmed002`, ...
  - Passwords are random 6-digit numbers. The seed for random password generation is passed at the time `docker run` is invoked.
  - Course materials are automatically placed inside the home directory of each user. To save space, only `exercises` and `solutions` folders are copied.
- Optionally, installs a list of additional R packages.
  - GitHub R packages are supported.
- Automatically activates and deactivates the supplied RStudio Server Pro license when the docker container is started or stopped.

## Configuration

Note that running the RStudio Server Pro Docker image requires the container to run using the `--privileged` flag and a valid RStudio Server Pro license. The image also expects an `/etc/rstudio` folder which customarily is mounted from a local directory named `server-pro/conf`.

## Example use

### Build the docker image locally

```bash
docker build -t rsp-train .
```

### Start the RStudio Server

The following example will start an RStudio Server Pro instance with `shiny`, `flexdashboard`, and `plotly` packages from CRAN, as well as the GitHub `rstudio/DT` package from GitHub, installed globally. One hundred users will be created, named `train001`, `train002`, ... `train100`. Each user's home directory will have a copy of the `exercises` and `solutions` folders from the `skadauke/intro-to-r-for-clinicians-rmed2020` GitHub repository, as well as a folder titled `backup/` which contains another copy of the `exercises` folder (This comes in handy if the learner accidentally deletes or otherwise changes an exercise file).

```bash
# Replace with valid license
export RSP_LICENSE=XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX

docker run --privileged -it \
    -p 8787:8787 \
    -e USER_PREFIX=train \
    -e N_USERS=100 \
    -e PW_SEED=12345 \
    -e GH_REPO=https://github.com/skadauke/intro-to-r-for-clinicians-rmed2020 \
    -e R_PACKAGES=shiny,flexdashboard,plotly \
    -e R_PACKAGES_GH=rstudio/DT \
    -e RSP_LICENSE=$RSP_LICENSE \
    -v "$PWD/server-pro/conf/":/etc/rstudio \
    rsp-train
```

Open [`http://localhost:8787`](http://localhost:8787) to access RStudio Server Pro.

### List usernames and passwords

The `create_users_table.R` script is used by the startup script to generate users and can be invoked to create a list of usernames and passwords.

```asis
Usage: ./create_users_table.R <user_prefix> <n_users> <pw_seed> <filename>
```

For example, to create the list of 100 users with the same seed as in the `docker run` command above, type:

```bash
./create_users_table.R train 100 12345 users.txt
```

This generates the file `users.txt` which is a tab delimited file listing usernames and passwords.

## Deploy to Amazon Web Services Elastic Compute Cloud (AWS EC2)

The following instructions explain how to set up an RSP training instance on AWS for teaching.

1. Push the image to Docker Hub (optional, if you have modified the `Dockerfile`. Substitute your Docker Hub username for `<your_username>`):

```bash
docker build <your_username>/rsp-train .
docker push <your_username>/rsp-train 
```

2. Create an EC2 instance with the following properties:

   - Ubuntu 20.04 LTS AMI
   - Select a machine size large enough for the expected load. Individual RStudio.cloud instances are 1 GB and 1 core. So for a workshop with 30 participants, I would suggest a machine with 32-64GB and 16-32 cores. For testing, the "free tier eligible" `t2.micro` machine (1 GB, 1 core) works well.
   - Configure the security group to allow inbound HTTP and HTTPS traffic (ports 80 and 443)
   - Create a key pair named `rsp-train`

3. Note the **Public IPv4 address** of the machine.

4. Create a domain name for your server. One way to do this is using AWS' Route 53 service.

    Note: register your domain early. It may take up to 3 days for the domain registration to be processed (although in my case it took about half an hour).

5. Create a hosted zone in Route 53 for your domain name. (If you just registered the domain name, Route 53 will have created a hosted zone for you). Within the hosted zone, create a new DNS record (record type **A**) that points the host name to the IP of your server. For more information, see [here](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-ec2-instance.html)

6. Log into the machine, substituting <your_server> for either the public IPv4 address or the domain name of the server.

```bash
ssh -i rsp-train.pem ubuntu@<your_server>
```

Enter "yes" if asked if you want to connect. If you get a warning about an unprotected privae key file, change permissions to user read-only by running `chmod 0400 rsp-train.pem`.

7. Update packages and set up a firewall

```bash
sudo apt update

sudo ufw allow OpenSSH
sudo ufw enable
```

8. Install Nginx and configure reverse proxy with HTTPS redirect with a TLS/SSL certificate from Letsencrypt.

```bash
sudo apt install nginx
sudo ufw allow 'Nginx Full'
sudo systemctl start nginx
sudo systemctl enable nginx
```

Check that your server is accessible from http://<your_server>.

Substitute `<your_domain>` with the domain name you registered:

```bash
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

sudo certbot --nginx -d <your_domain>
```

Enter your email when prompted.

If this worked successfully, then anyone who connects to http://<your_server> will be automatically redirected to a secure HTTPS connection (https://<your_server>), and the TLS certificate should be valid.

9. Set up Docker

```bash
sudo apt update
sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io
```

10. Set up the RSP-train application. Substitute <license> with your RSP license. Also, for security reasons, it's highly recommended that you change the `PW_SEED`.

```bash
sudo docker pull skadauke/rsp-train

export RSP_LICENSE=<license>

sudo docker run --privileged -it \
    --detach-keys "ctrl-a" \
    --restart unless-stopped \
    -p 8787:8787 -p 5559:5559 \
    -e USER_PREFIX=apir \
    -e GH_REPO=https://github.com/amromeo/api_r2021 \
    -e R_PACKAGES=shiny,flexdashboard,plotly,DT \
    -e N_USERS=100 \
    -e PW_SEED=12345 \
    -e RSP_LICENSE=$RSP_LICENSE \
    -v "$PWD/server-pro/conf/":/etc/rstudio \
    skadauke/rsp-train
```

After the Docker container has started up, press Ctrl+A to detach the image. This will allow you to take back control of the console. The container will continue to run in the background.

11. Configure Nginx to forward traffic to the Docker container

Below, substitute `<my_hostname>` with the domain name of your host.

Inside the `/etc/nginx/sites-available/default` file, replace the following lines:

```conf
location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to displaying a 404.
        try_files $uri $uri/ =404;
}  
```

With the following:

```conf
location / {
    proxy_pass http://localhost:8787;
    proxy_redirect http://localhost:8787/ $scheme://$http_host/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_read_timeout 20d;
}
```

Add the following lines right after `http {` in `/etc/nginx/nginx.conf`:

```conf
        map $http_upgrade $connection_upgrade {
            default upgrade;
            ''      close;
        }

        server_names_hash_bucket_size 64;
```

Test the configuration and restart Nginx:

```bash
sudo nginx -t
sudo systemctl restart nginx
```

### Troubleshooting

Manually deactivating the license: http://apps.rstudio.com/deactivate-license/

### Teardown

To stop getting charged, you will want to remove the following after you are done:

- EC2 instance
- Hosted zone

### Expected cost

- Domain name: varies, prices between $10-$50/year are typical
- EC2 instance: it depends on the size and how long you have it up. For a workshop with 30 participants, you might want to use a `a1.4xlarge` instance which costs $0.408 per hour, which comes out to $9.79 per day. To save money, you can first create a small testing instance and then, the day prior to the workshop, replace it with a beefier instance. For multi-day workshops, you can also stop the instance at the end of the day and restart it at the beginning of the next day.