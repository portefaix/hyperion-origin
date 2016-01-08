

resource "template_file" "origin-master-service" {
  template = "../origin-master.service"
}


# Network
resource "google_compute_network" "hyperion-network" {
  name = "hyperion-network"
  ipv4_range = "${var.gce_ipv4_range}"
}

# Firewall
resource "google_compute_firewall" "hyperion-firewall-external" {
  name = "hyperion-firewall-external"
  network = "${google_compute_network.hyperion-network.name}"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = [
      "22",   # SSH
      "80",   # HTTP
      "443",  # HTTPS
      "8443", # Openshift Origin API
      "8080", # Openshift Origin console
      "8442", # Openshift Origin OAuth
    ]
  }

}

resource "google_compute_firewall" "hyperion-firewall-internal" {
  name = "hyperion-firewall-internal"
  network = "${google_compute_network.hyperion-network.name}"
  source_ranges = ["${google_compute_network.hyperion-network.ipv4_range}"]

  allow {
    protocol = "tcp"
    ports = ["1-65535"]
  }

  allow {
    protocol = "udp"
    ports = ["1-65535"]
  }
}


resource "google_compute_address" "hyperion-master" {
  name = "hyperion-master"
}

resource "google_compute_instance" "hyperion-master" {
  zone = "${var.gce_zone}"
  name = "${var.cluster_name}-master"
  description = "Rancher master"
  machine_type = "${var.gce_machine_type_master}"

  disk {
    image = "${var.gce_image}"
    auto_delete = true
  }
  metadata {
    sshKeys = "${var.gce_ssh_user}:${file("${var.gce_ssh_public_key}")}"
    ssh_user = "${var.gce_ssh_user}"
  }
  network_interface {
    network = "${google_compute_network.hyperion-network.name}"
    access_config {}
  }
  connection {
    user = "${var.gce_ssh_user}"
    key_file = "${var.gce_ssh_private_key_file}"
    agent = false
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cat <<'EOF' > /tmp/origin-master.service\n${template_file.origin-master-service.rendered}\nEOF",
      "sudo mv /tmp/origin-master.service /usr/lib/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable origin-master.service",
      "sudo /usr/local/bin/openshift start master --write-config=/etc/origin/master",
      "sudo systemctl start origin-master.service"
    ]
  }
  depends_on = [
    "template_file.origin-master-service"
  ]

}
