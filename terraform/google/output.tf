output "origin-server" {
    value = "Go to https://${google_compute_instance.hyperion-master.network_interface.0.access_config.0.nat_ip}:8443/console"
}
