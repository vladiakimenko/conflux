
#!/usr/bin/env bash

validate_name() {
    local name="${1:-}"

    [[ -n "$name" ]] ||
        die "Forwarder name is required."

    [[ "$name" =~ ^[a-z0-9][a-z0-9_.-]*$ ]] ||
        die "Invalid name. Use lowercase letters, numbers, dots, underscores and hyphens."

    ((${#name} <= 50)) ||
        die "Forwarder name is too long (maximum 50 characters)."
}

validate_protocol() {
    case "${1:-}" in
        tcp|udp)
            ;;
        *)
            die "Protocol must be tcp or udp."
            ;;
    esac
}

validate_port() {
    local port="${1:-}"

    [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] ||
        die "Invalid port: $port"

    ((10#$port <= 65535)) ||
        die "Port must be between 1 and 65535."
}

validate_ipv4() {
    local ip="${1:-}"
    local octet
    local -a octets

    [[ "$ip" =~ ^(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})$ ]] ||
        die "Invalid IPv4 address: $ip"

    IFS='.' read -r -a octets <<< "$ip"

    for octet in "${octets[@]}"; do
        ((10#$octet <= 255)) ||
            die "Invalid IPv4 address: $ip"
    done
}
