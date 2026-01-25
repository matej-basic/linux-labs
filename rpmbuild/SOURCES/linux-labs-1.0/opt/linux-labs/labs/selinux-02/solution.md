# Solution: selinux-02

```bash
# 1) Create app structure and seed files under /webapp
sudo mkdir -p /webapp/{www,config,data}
sudo bash -c 'cat <<"EOF" > /webapp/www/index.html
<!DOCTYPE html>
<html><body><h1>MyApp</h1><p>SELinux lab test page.</p></body></html>
EOF'
sudo bash -c 'echo "db_host=localhost" > /webapp/config/db.conf'
sudo bash -c 'echo "test log" > /webapp/data/app.log'

# 2) Install and start Apache
sudo dnf install -y httpd
sudo systemctl enable --now httpd

# 3) Configure virtual host pointing to /webapp/www
sudo tee /etc/httpd/conf.d/myapp.conf > /dev/null <<'EOF'
<VirtualHost *:80>
	ServerName localhost
	DocumentRoot /webapp/www
    <Directory /webapp/www>
	DirectoryIndex index.html
		AllowOverride None
		Require all granted
	</Directory>
	ErrorLog /var/log/httpd/myapp-error.log
	CustomLog /var/log/httpd/myapp-access.log combined
</VirtualHost>
EOF
sudo systemctl restart httpd  # restart so DocumentRoot exists before Apache loads

# 4) Apply SELinux context for Apache read/write
sudo chcon -R -t httpd_sys_rw_content_t /webapp/www
# (Optional persistent mapping)
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/webapp/www(/.*)?"
sudo restorecon -R /webapp/www

# 5) Verify context and service
ls -Z /webapp/www/index.html
sudo systemctl status httpd --no-pager

# 6) Grade
sudo labctl grade selinux-02
```
