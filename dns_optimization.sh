#!/bin/bash

# DNS Optimization Script with Before/After Comparison
# Focuses on DNS-related improvements for network responsiveness
# Compatible with macOS default bash 3.2
#
# Usage:
#   ./dns_optimization.sh          - Run DNS optimization
#   ./dns_optimization.sh --restore - Restore backed up DNS settings
#   ./dns_optimization.sh --help    - Show help message

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Backup file location
BACKUP_FILE="$HOME/dns_backup.txt"

# Test domains for DNS benchmarking
TEST_DOMAINS=("google.com" "amazon.com" "github.com" "apple.com" "cloudflare.com")

# DNS servers to test (using parallel arrays for bash 3.2 compatibility)
DNS_NAMES=("Cloudflare" "Google" "Quad9" "OpenDNS")
DNS_IPS=("1.1.1.1" "8.8.8.8" "9.9.9.9" "208.67.222.222")
DNS_SECONDARY=("1.0.0.1" "8.8.4.4" "149.112.112.112" "208.67.220.220")

# ============================================
# FUNCTION: Show Help
# ============================================
show_help() {
    echo "DNS Optimization Script"
    echo ""
    echo "Usage:"
    echo "  $0              Run DNS optimization and testing"
    echo "  $0 --restore    Restore previously backed up DNS settings"
    echo "  $0 --help       Show this help message"
    echo ""
    echo "The script will backup your current DNS settings to:"
    echo "  $BACKUP_FILE"
    echo ""
    exit 0
}

# ============================================
# FUNCTION: Restore DNS Settings
# ============================================
restore_dns() {
    echo "=========================================="
    echo "  DNS Settings Restoration"
    echo "=========================================="
    echo ""
    
    # Check if backup file exists
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}Error: Backup file not found at $BACKUP_FILE${NC}"
        echo "No DNS settings to restore."
        exit 1
    fi
    
    # Get Wi-Fi network service
    echo "Detecting Wi-Fi network service..."
    NETWORK_SERVICE=$(networksetup -listallnetworkservices | grep -i "wi-fi\|wifi" | head -1)
    
    if [ -z "$NETWORK_SERVICE" ]; then
        # Fallback: try to find the active service
        NETWORK_SERVICE=$(networksetup -listallnetworkservices | grep -v "*" | grep -v "USB" | head -2 | tail -1)
    fi
    
    echo -e "${BLUE}Using network service: $NETWORK_SERVICE${NC}"
    echo ""
    
    # Read backup file
    BACKUP_CONTENT=$(cat "$BACKUP_FILE")
    
    echo "Backed up DNS settings:"
    echo "$BACKUP_CONTENT"
    echo ""
    
    # Check if it was DHCP or custom DNS
    if [ "$BACKUP_CONTENT" = "DHCP" ]; then
        echo "Restoring to DHCP (automatic) DNS..."
        sudo networksetup -setdnsservers "$NETWORK_SERVICE" Empty
        echo -e "${GREEN}✓ DNS restored to DHCP (automatic)${NC}"
    else
        echo "Restoring custom DNS servers..."
        # Convert backup content to array (bash 3.2 compatible)
        DNS_ARRAY=()
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                DNS_ARRAY+=("$line")
            fi
        done <<< "$BACKUP_CONTENT"
        
        # Apply DNS servers
        if [ ${#DNS_ARRAY[@]} -gt 0 ]; then
            sudo networksetup -setdnsservers "$NETWORK_SERVICE" "${DNS_ARRAY[@]}"
            echo -e "${GREEN}✓ DNS servers restored${NC}"
        else
            echo -e "${RED}Error: Invalid backup content${NC}"
            exit 1
        fi
    fi
    
    # Flush DNS cache
    echo ""
    echo "Flushing DNS cache..."
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    echo -e "${GREEN}✓ DNS cache flushed${NC}"
    
    # Show current DNS
    echo ""
    echo "Current DNS servers:"
    networksetup -getdnsservers "$NETWORK_SERVICE"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}DNS settings successfully restored!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    exit 0
}

# ============================================
# PARSE COMMAND LINE ARGUMENTS
# ============================================
if [ "$1" = "--restore" ]; then
    restore_dns
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
elif [ -n "$1" ]; then
    echo -e "${RED}Error: Unknown option '$1'${NC}"
    echo "Use --help for usage information"
    exit 1
fi

# ============================================
# MAIN SCRIPT STARTS HERE
# ============================================
echo "=========================================="
echo "  DNS Optimization with Before/After Test"
echo "=========================================="
echo ""

# Get Wi-Fi network service
echo "Detecting Wi-Fi network service..."
NETWORK_SERVICE=$(networksetup -listallnetworkservices | grep -i "wi-fi\|wifi" | head -1)

if [ -z "$NETWORK_SERVICE" ]; then
    # Fallback: try to find the active service
    NETWORK_SERVICE=$(networksetup -listallnetworkservices | grep -v "*" | grep -v "USB" | head -2 | tail -1)
fi

echo -e "${BLUE}Using network service: $NETWORK_SERVICE${NC}"
echo ""

# Verify Wi-Fi is active
WIFI_STATUS=$(networksetup -getairportpower en0 2>/dev/null | awk '{print $4}')
if [ "$WIFI_STATUS" = "Off" ]; then
    echo -e "${RED}Warning: Wi-Fi appears to be off${NC}"
    echo "Please enable Wi-Fi and run the script again"
    exit 1
fi

echo -e "${GREEN}✓ Wi-Fi is active${NC}"
echo ""

# ============================================
# FUNCTION: Test DNS Performance
# ============================================
test_dns_performance() {
    local dns_server=$1
    local dns_name=$2
    local total_time=0
    local test_count=0
    
    echo -e "${YELLOW}Testing $dns_name DNS ($dns_server)...${NC}"
    
    for domain in "${TEST_DOMAINS[@]}"; do
        if [ "$dns_server" = "current" ]; then
            # Test current DNS
            result=$(dig +time=2 +tries=1 "$domain" 2>&1 | grep "Query time:" | awk '{print $4}')
        else
            # Test specific DNS server
            result=$(dig @"$dns_server" +time=2 +tries=1 "$domain" 2>&1 | grep "Query time:" | awk '{print $4}')
        fi
        
        if [ -n "$result" ]; then
            echo "  $domain: ${result}ms"
            total_time=$((total_time + result))
            test_count=$((test_count + 1))
        else
            echo "  $domain: timeout"
        fi
    done
    
    if [ $test_count -gt 0 ]; then
        avg_time=$((total_time / test_count))
        echo -e "${GREEN}  Average: ${avg_time}ms${NC}"
        echo ""
        # Store result in global variable instead of return code
        DNS_TEST_RESULT=$avg_time
    else
        echo -e "${RED}  Failed to get results${NC}"
        echo ""
        DNS_TEST_RESULT=999
    fi
}

# ============================================
# STEP 1: BENCHMARK CURRENT DNS
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 1: BENCHMARK CURRENT DNS PERFORMANCE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show current DNS servers
CURRENT_DNS=$(networksetup -getdnsservers "$NETWORK_SERVICE")
echo "Current DNS servers:"
if [[ "$CURRENT_DNS" == *"aren't any"* ]]; then
    echo -e "${YELLOW}Using DHCP-provided DNS (automatic)${NC}"
    CURRENT_DNS="DHCP"
    
    # Get actual DNS being used from system
    echo ""
    echo "Actual DNS servers in use:"
    scutil --dns | grep "nameserver\[0\]" | head -3
    echo ""
else
    echo "$CURRENT_DNS"
    echo ""
fi

# Test current DNS performance
echo "Testing current DNS performance (this may take 10-15 seconds)..."
test_dns_performance "current" "Current"
BEFORE_AVG=$DNS_TEST_RESULT

# ============================================
# STEP 2: TEST ALTERNATIVE DNS SERVERS
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 2: TEST ALTERNATIVE DNS SERVERS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Testing each DNS provider with fresh cache for fair comparison..."
echo ""

# Store results in parallel arrays
DNS_RESULT_TIMES=()

for i in "${!DNS_NAMES[@]}"; do
    dns_name="${DNS_NAMES[$i]}"
    dns_server="${DNS_IPS[$i]}"
    
    # Flush DNS cache before each test for fair comparison
    echo "Flushing DNS cache before testing $dns_name..."
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    sleep 1
    
    test_dns_performance "$dns_server" "$dns_name"
    DNS_RESULT_TIMES+=($DNS_TEST_RESULT)
done

# ============================================
# STEP 3: SHOW COMPARISON
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 3: DNS PERFORMANCE COMPARISON${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

printf "%-20s %-15s %-20s\n" "DNS Provider" "Avg Response" "vs Current"
echo "────────────────────────────────────────────────────────"
printf "%-20s %-15s %-20s\n" "Current DNS" "${BEFORE_AVG}ms" "baseline"

# Find fastest DNS
FASTEST_DNS=""
FASTEST_TIME=999
FASTEST_NAME=""
FASTEST_INDEX=-1

for i in "${!DNS_NAMES[@]}"; do
    dns_name="${DNS_NAMES[$i]}"
    avg_time=${DNS_RESULT_TIMES[$i]}
    
    if [ $avg_time -lt 999 ]; then
        improvement=$((BEFORE_AVG - avg_time))
        percent=$((improvement * 100 / BEFORE_AVG))
        
        if [ $improvement -gt 0 ]; then
            printf "%-20s %-15s ${GREEN}%-20s${NC}\n" "$dns_name" "${avg_time}ms" "↓ ${improvement}ms (${percent}% faster)"
        elif [ $improvement -lt 0 ]; then
            improvement=$((improvement * -1))
            percent=$((improvement * 100 / BEFORE_AVG))
            printf "%-20s %-15s ${RED}%-20s${NC}\n" "$dns_name" "${avg_time}ms" "↑ ${improvement}ms (${percent}% slower)"
        else
            printf "%-20s %-15s %-20s\n" "$dns_name" "${avg_time}ms" "same"
        fi
        
        # Track fastest
        if [ $avg_time -lt $FASTEST_TIME ]; then
            FASTEST_TIME=$avg_time
            FASTEST_DNS="${DNS_IPS[$i]}"
            FASTEST_NAME="$dns_name"
            FASTEST_INDEX=$i
        fi
    fi
done

echo ""

# ============================================
# STEP 4: RECOMMENDATION
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 4: RECOMMENDATION${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -n "$FASTEST_DNS" ]; then
    improvement=$((BEFORE_AVG - FASTEST_TIME))
    percent=$((improvement * 100 / BEFORE_AVG))
    
    echo -e "${GREEN}Fastest DNS: $FASTEST_NAME ($FASTEST_DNS)${NC}"
    echo "Average response time: ${FASTEST_TIME}ms"
    echo "Improvement: ${improvement}ms faster (${percent}% improvement)"
    echo ""
    
    read -p "Switch to $FASTEST_NAME DNS? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Backup current DNS
        if [ "$CURRENT_DNS" != "DHCP" ]; then
            echo "$CURRENT_DNS" > "$BACKUP_FILE"
            echo "Current DNS backed up to $BACKUP_FILE"
        else
            echo "DHCP" > "$BACKUP_FILE"
            echo "Current setting (DHCP) backed up to $BACKUP_FILE"
        fi
        
        # Switch DNS using the fastest server
        primary_dns="${DNS_IPS[$FASTEST_INDEX]}"
        secondary_dns="${DNS_SECONDARY[$FASTEST_INDEX]}"
        sudo networksetup -setdnsservers "$NETWORK_SERVICE" "$primary_dns" "$secondary_dns"
        
        echo -e "${GREEN}✓ DNS switched to $FASTEST_NAME${NC}"
        
        # ============================================
        # STEP 5: FLUSH DNS CACHE
        # ============================================
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}STEP 5: FLUSH DNS CACHE${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        echo "Flushing DNS cache..."
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder
        echo -e "${GREEN}✓ DNS cache flushed${NC}"
        
        # ============================================
        # STEP 6: VERIFY NEW DNS PERFORMANCE
        # ============================================
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}STEP 6: VERIFY NEW DNS PERFORMANCE${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        sleep 2  # Wait for DNS change to propagate
        
        test_dns_performance "current" "New DNS"
        AFTER_AVG=$DNS_TEST_RESULT
        
        # ============================================
        # FINAL COMPARISON
        # ============================================
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}BEFORE vs AFTER COMPARISON${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        printf "%-20s %-15s\n" "Metric" "Value"
        echo "────────────────────────────────────────"
        printf "%-20s %-15s\n" "Before (old DNS)" "${BEFORE_AVG}ms"
        printf "%-20s %-15s\n" "After (new DNS)" "${AFTER_AVG}ms"
        
        improvement=$((BEFORE_AVG - AFTER_AVG))
        percent=$((improvement * 100 / BEFORE_AVG))
        
        if [ $improvement -gt 0 ]; then
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}IMPROVEMENT: ${improvement}ms faster (${percent}% improvement)${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        elif [ $improvement -lt 0 ]; then
            improvement=$((improvement * -1))
            percent=$((improvement * 100 / BEFORE_AVG))
            echo ""
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${RED}SLOWER: ${improvement}ms slower (${percent}% worse)${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        else
            echo ""
            echo "No significant change"
        fi
        
        echo ""
        echo "New DNS servers:"
        networksetup -getdnsservers "$NETWORK_SERVICE"
        
    else
        echo "DNS not changed"
    fi
else
    echo -e "${RED}Could not determine fastest DNS${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}ADDITIONAL DNS OPTIMIZATIONS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "To restore backed up DNS settings:"
echo "  sudo ./dns_optimization.sh --restore"
echo ""
echo "To manually revert to automatic/DHCP DNS:"
echo "  sudo networksetup -setdnsservers \"$NETWORK_SERVICE\" Empty"
echo ""

echo "To manually set DNS:"
echo "  System Settings > Network > $NETWORK_SERVICE > Details > DNS"
echo ""

echo "Browser DNS optimizations:"
echo "  • Disable DNS prefetching in browser settings"
echo "  • Clear browser DNS cache"
echo "  • Consider using DNS over HTTPS (DoH)"
echo ""

echo "Monitor DNS performance:"
echo "  dig google.com"
echo "  nslookup google.com"
echo "  time dig google.com"
echo ""

# Made with Bob