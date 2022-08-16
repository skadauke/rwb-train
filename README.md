# RStudio Server Pro Training Environment

Docker image for an Intro to R training environment using RStudio Workbench (formerly called RStudio Server Pro). This image is based on [rstudio/rstudio-workbench](https://hub.docker.com/r/rstudio/rstudio-workbench). It automatically generates a configurable number (up to 999) of training accounts, which can be useful for Intro to R courses such as [Intro to R for Clinical Data](https://github.com/skadauke/intro-to-r-for-clinical-data-rmed2022) at the [R/Medicine 2022 Virtual Conference](https://r-medicine.org).

## Features

The `Dockerfile` extends [rstudio/rstudio-workbench](https://hub.docker.com/r/rstudio/rstudio-workbench) by adding:

- The `libxml2-dev`, `vim`, and `git` packages
- The `tidyverse`, `rmarkdown`, and `devtools` R packages

In addition, the startup script accomplishes the following:

- Clones a GitHub repository with course materials.
  - Repos must contain two folders labeled `exercises` and `solutions`.
  - For an example repo, see <https://github.com/skadauke/intro-to-r-for-clinical-data-rmed2022>.
- Creates a configurable number of users with a configurable prefix, e.g. `train001`, `train002`, ... or `rmed001`, `rmed002`, ...
  - Passwords are random 6-digit numbers. The seed for random password generation is passed at the time `docker run` is invoked.
  - Course materials are automatically placed inside the home directory of each user. To save space, only `exercises` and `solutions` folders are copied.
- Optionally, installs a list of additional R packages.
  - GitHub R packages are supported.
- Automatically activates and deactivates the supplied RStudio Server Pro license when the docker container is started or stopped.

## Configuration

Note that running the RStudio Workbench Docker image requires the container to run using the `--privileged` flag and a valid RStudio Workbench license. The image also expects an `/etc/rstudio` folder which customarily is mounted from a local directory named `server-pro/conf`.

## Example use

### Build the docker image locally

```bash
docker build -t rwb-train .
```

### Start the RStudio Server

The following example will start an RStudio Workbench instance with `shiny`, `flexdashboard`, and `plotly` packages from CRAN, as well as the `rstudio/DT` package from GitHub, installed globally. One hundred users will be created, named `rmed001`, `rmed002`, ... `rmed100`. Each user's home directory will have a copy of the `exercises` and `solutions` folders from the `skadauke/intro-to-r-for-clinical-data-rmed2022` GitHub repository, as well as a folder titled `backup` which contains another copy of the `exercises` folder (This comes in handy if the learner accidentally deletes or otherwise changes an exercise file).

```bash
# Replace with valid license
export RSP_LICENSE=XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX

docker run --privileged -it \
    -p 8787:8787 \
    -e USER_PREFIX=rmed \
    -e N_USERS=100 \
    -e PW_SEED=12345 \
    -e GH_REPO=https://github.com/skadauke/intro-to-r-for-clinical-data-rmed2022 \
    -e R_PACKAGES=shiny,flexdashboard,plotly \
    -e R_PACKAGES_GH=rstudio/DT \
    -e RSP_LICENSE=$RSP_LICENSE \
    -v "$PWD/server-pro/conf/":/etc/rstudio \
    rwb-train
```

Open [`http://localhost:8787`](http://localhost:8787) to access RStudio Workbench.

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

The following instructions explain how to set up an RWB training instance on AWS for teaching.

1. Push the image to Docker Hub (optional, only needed if you have modified the `Dockerfile`. Substitute your Docker Hub username for `<your_username>`):

```bash
docker build <your_username>/rwb-train
docker push <your_username>/rwb-train
```

2. Create an EC2 instance with the following properties:

   - Ubuntu 20.04 (or later) LTS AMI
   - Select a machine size large enough for the expected load. Individual RStudio.cloud instances are 1 GB and 1 core. So for a workshop with 30 participants, I would suggest a machine with 32-64GB and 16-32 cores. For testing, the "free tier eligible" `t2.micro` machine (1 GB, 1 core) works well.
   - Create a key pair if you don't already have one. Move the `.pem` file to `~/.ssh/` of your local machine. Change the permissions to be readable only by root `chmod 400 my-key-file.pem`.
   - Configure the security group to allow inbound HTTP and HTTPS traffic (ports 80 and 443)
   - Ensure there is enough storage. I would suggest 1 GB per participant.

3. Note the **Public IPv4 address** of the machine.

4. Optional but highly recommended: Create an Elastic IP for your machine. This will allow you to avoid the hassle of changing your IP address in DNS records every time you shut down and restart your server. From within EC2, allocate an "Elastic IP" address and associate it with your instance.

5. Optional: create a domain name for your server. One way to do this is using AWS' Route 53 service.

    Note: register your domain early. It may take up to 3 days for the domain registration to be processed (although in my case it took about half an hour), and it may take up to 72 hours for the DNS record to propagate through the internet.

6. Create a hosted zone in Route 53 for your domain name. (If you just registered the domain name, Route 53 will have created a hosted zone for you). Within the hosted zone, create a new DNS record (record type **A**) that points the host name to the IP of your server. For more information, see [here](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-ec2-instance.html).

7. Log into the machine, substituting `<path-to-your-pem-file>` for the path to the `.pem` key file, and `<your_server>` for either the public IPv4 address or the domain name of the server.

```bash
ssh -i <path-to-your-pem-file> ubuntu@<your_server>
```

Enter "yes" if asked if you want to connect. If you get a warning about an unprotected private key file, change permissions to user read-only by running `chmod 0400 <path-to-your-pem-file>`.

7. Update packages and set up a firewall

```bash
sudo apt update &&
sudo apt upgrade &&

sudo ufw allow OpenSSH &&
sudo ufw enable
```

8. Install Nginx and configure reverse proxy with HTTPS redirect with a TLS/SSL certificate from Letsencrypt.

```bash
sudo apt install nginx &&
sudo ufw allow 'Nginx Full' &&
sudo systemctl start nginx &&
sudo systemctl enable nginx
```

Check that your server is accessible from http://<your_server>.

Substitute `<your_domain>` with the domain name you registered:

```bash
sudo snap install --classic certbot &&
sudo ln -s /snap/bin/certbot /usr/bin/certbot

sudo certbot --nginx -d <your_domain>
```

Enter your email when prompted.

If this worked successfully, then anyone who connects to http://<your_server> will be automatically redirected to a secure HTTPS connection (https://<your_server>), and the TLS certificate should be valid.

9. Set up Docker

```bash
sudo apt update &&
sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release &&

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg &&

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update &&
sudo apt install docker-ce docker-ce-cli containerd.io
```

10. Set up the RSP-train application. Substitute <license> with your RSP license. Also, for security reasons, it's highly recommended that you change the `PW_SEED`.

```bash
sudo docker pull skadauke/rwb-train

export RSP_LICENSE=<license>

sudo docker run --privileged -it \
    --detach-keys "ctrl-a" \
    --restart unless-stopped \
    -p 8787:8787 -p 5559:5559 \
    -e USER_PREFIX=rmed \
    -e GH_REPO=https://github.com/skadauke/intro-to-r-for-clinical-data-rmed2022 \
    -e R_PACKAGES=shiny,flexdashboard,plotly,DT,markdown \
    -e N_USERS=100 \
    -e PW_SEED=12345 \
    -e RSP_LICENSE=$RSP_LICENSE \
    -v "$PWD/server-pro/conf/":/etc/rstudio \
    skadauke/rwb-train
```

After the Docker container has started up, press Ctrl+A to detach the image. This will allow you to take back control of the console. The container will continue to run in the background.

11. Copy the usernames and passwords for the training users on the instance - scroll up in your terminal to find them. You will need to hand these out to participants.

12. Configure Nginx to forward traffic to the Docker container

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
sudo nginx -t &&
sudo systemctl restart nginx
```

### Stopping and scaling

Note: While you are setting up the instance, you may want to stop the VM to save money. If you associated an elastic IP, starting it back up should restore a fully functional environment.

1. Once you are satisfied with the configuration of the instance, you can create an image (AMI, Amazon Machine Image). In the EC2 dashboard, right-click on the instance and choose **Create Image**. You may have to stop the instance to make the image available.
2. On the **AMIs** page in EC2, click the AMI you created and **Launch instance from AMI**. Give it a name, select an appropriate instance size, select the key pair, allow HTTP and HTTPS and make sure there is enough storage as above. Launch the instance
3. Associate your instance with the elasic IP.

### Refreshing the materials

- To refresh the materials before the workshop, for example to incorporate any last changes to exercises and solutions, first terminate the docker container. Of note, this will erase all training users and everything that's stored inside of their folders. You may then restart the docker container with the appropriate `docker run` command (see above for examples).

```bash
# The following commands stop and remove *all* docker containers - proceed with caution!
sudo docker kill $(sudo docker ps -q) &&
sudo docker rm $(sudo docker ps -a -q)
```

### Teardown

To stop getting charged, you will want to remove the following after you are done:

- EC2 instance
- Hosted zone
- Custom images

### Troubleshooting

Manually deactivating the license: http://apps.rstudio.com/deactivate-license/

### Expected cost

- Domain name: varies, prices between $10-$50/year are typical
- EC2 instance: it depends on the size and how long you have it up. For a workshop with 30 participants, you might want to use a `a1.4xlarge` instance which costs $0.408 per hour, which comes out to $9.79 per day. To save money, you can first create a small testing instance and then, the day prior to the workshop, replace it with a beefier instance. For multi-day workshops, you can also stop the instance at the end of the day and restart it at the beginning of the next day.
