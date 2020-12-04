# updating yum and install git + apache
sudo yum update -y httpd git
sudo yum install -y httpd git
# start Apache server
sudo systemctl start httpd
# clone a website from a public repository to /var/www/html
git clone https://github.com/microsoft/project-html-website.git /var/www/html
