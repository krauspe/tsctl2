sed -i '/^After=network.target/d' /usr/lib/systemd/system/gdm.service
sed -i 's/^\[Service\]/After=network.target\n[Service]/'  /usr/lib/systemd/system/gdm.service
