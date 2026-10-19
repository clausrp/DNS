# DNS Optimization & Benchmarking Script for macOS

A fast, lightweight macOS bash script to benchmark multiple DNS providers, select the lowest-latency DNS resolver for your active network connection, and optimize DNS cache settings.

## Features

- **DNS Latency Benchmarking**: Tests and compares query response times against top secure public DNS providers:
  - Cloudflare (`1.1.1.1` / `1.0.0.1`)
  - Google DNS (`8.8.8.8` / `8.8.4.4`)
  - Quad9 (`9.9.9.9` / `149.112.112.112`)
  - OpenDNS (`208.67.222.222` / `208.67.220.220`)
- **Automated Backup & Restore**: Backs up your current DNS configuration to `~/dns_backup.txt` before applying any changes.
- **Before/After Latency Comparison**: Verifies speed improvements across real-world test domains.
- **DNS Cache Flush**: Cleans local mDNSResponder and directory service caches.
- **Compatibility**: Compatible with default macOS bash (v3.2+) and zsh.

## Usage

### Run Optimization
```bash
chmod +x dns_optimization.sh
./dns_optimization.sh
```

### Restore Previous Settings
```bash
./dns_optimization.sh --restore
```

### Help
```bash
./dns_optimization.sh --help
```
