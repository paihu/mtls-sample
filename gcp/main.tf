
data "google_dns_managed_zone" "this" {
  name = var.zone_name
}
resource "google_dns_record_set" "this" {
  name    = "mtls-test.${data.google_dns_managed_zone.this.dns_name}"
  type    = "A"
  ttl     = 300
  rrdatas = [google_compute_global_forwarding_rule.this.ip_address]

  managed_zone = data.google_dns_managed_zone.this.name
}

resource "google_compute_global_forwarding_rule" "this" {
  name                  = "mtls-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  ip_protocol           = "TCP"
  target                = google_compute_target_https_proxy.this.id
}

resource "google_compute_target_https_proxy" "this" {
  provider          = google-beta
  name              = "test-proxy"
  url_map           = google_compute_url_map.this.id
  ssl_certificates  = [google_compute_managed_ssl_certificate.this.id]
  server_tls_policy = google_network_security_server_tls_policy.this.id
}

resource "google_compute_managed_ssl_certificate" "this" {
  name = "test-cert"

  managed {
    domains = ["mtls-test.${data.google_dns_managed_zone.this.dns_name}"]
  }
}

resource "google_network_security_server_tls_policy" "this" {
  provider   = google-beta
  name       = "mtls-tls-policy"
  location   = "global"
  allow_open = "false"

  mtls_policy {
    client_validation_mode         = "ALLOW_INVALID_OR_MISSING_CLIENT_CERT"
    client_validation_trust_config = google_certificate_manager_trust_config.this.id
  }

  lifecycle {
    ignore_changes = [mtls_policy[0].client_validation_trust_config]
  }

}

resource "google_certificate_manager_trust_config" "this" {
  location    = "global"
  name        = "mtls-trust-config"
  description = "sample trust config description"

  trust_stores {
    trust_anchors {
      pem_certificate = file("../ca.crt")
    }
  }

}

resource "google_compute_url_map" "this" {
  name        = "url-map"
  description = "a description"

  default_service = google_compute_backend_service.this.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }
  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.this.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.this.id
    }
  }
}

resource "google_compute_backend_service" "this" {
  #provider   = google-beta
  name       = "mtls-backend-service"
  enable_cdn = false

  custom_request_headers = [
    "X-Client-Cert-Present: {client_cert_present}",
    "X-Client-Cert-Chain-Verified: {client_cert_chain_verified}",
    "X-Client-Cert-Error: {client_cert_error}",
    "X-Client-Cert-Sha256-Fingerprint: {client_cert_sha256_fingerprint}",
    "X-Client-Cert-Serial-Number: {client_cert_serial_number}",
    "X-Client-Cert-Valid-Not-Before: {client_cert_valid_not_before}",
    "X-Client-Cert-Valid-Not-After: {client_cert_valid_not_after}",
    "X-Client-Cert-Uri-Sans: {client_cert_uri_sans}",
    "X-Client-Cert-Dnsname-Sans: {client_cert_dnsname_sans}",
  ]
  backend {
    group = google_compute_region_network_endpoint_group.neg.id
  }
}


resource "google_compute_region_network_endpoint_group" "neg" {
  name                  = "my-lb-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_function {
    function = google_cloudfunctions_function.function_neg.name
  }
}

resource "google_cloudfunctions_function" "function_neg" {
  name        = "function-neg"
  description = "My function"
  runtime     = "nodejs18"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  timeout               = 60
  entry_point           = "mtls-test"
  ingress_settings      = "ALLOW_ALL"
}
resource "google_cloudfunctions_function_iam_member" "invoker" {
  cloud_function = google_cloudfunctions_function.function_neg.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_storage_bucket" "bucket" {
  name     = "${var.project_id}-mts-test-function"
  location = var.region
}

resource "google_storage_bucket_object" "archive" {
  name       = "index.zip"
  bucket     = google_storage_bucket.bucket.name
  source     = "function.zip"
  depends_on = [data.archive_file.function]
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "function"
  output_path = "function.zip"
}
