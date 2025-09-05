#!/usr/bin/env python3
"""
Kubernetes Audit Log Security Event Filter

This script filters Kubernetes audit logs to identify dangerous/malicious events
based on the security analysis of audit_5.log. It detects all attack vectors
found in the comprehensive security incident simulation.

Usage:
    python3 filter_dangerous_events.py <audit_log_path>
    
The script reads newline-delimited JSON audit logs and outputs only dangerous events.
"""

import json
import sys
import argparse
from typing import Dict, Any, List
import re


class DangerousEventFilter:
    """Filter for detecting dangerous Kubernetes audit events."""

    def __init__(self):
        """Initialize the filter with detection rules."""
        self.dangerous_events = []
        self.stats = {
            "total_events": 0,
            "dangerous_events": 0,
            "privileged_pods": 0,
            "exec_commands": 0,
            "debug_commands": 0,
            "rbac_escalation": 0,
            "secret_access": 0,
            "namespace_creation": 0,
            "impersonation": 0,
            "audit_policy_tampering": 0,
        }

    def is_privileged_pod_creation(self, event: Dict[str, Any]) -> bool:
        """Detect creation of privileged pods with dangerous settings."""
        if event.get("verb") == "create" and event.get("objectRef", {}).get("resource") == "pods":

            request_obj = event.get("requestObject", {})
            if request_obj.get("kind") == "Pod":
                spec = request_obj.get("spec", {})
                containers = spec.get("containers", [])

                # Check for privileged containers
                for container in containers:
                    security_context = container.get("securityContext", {})
                    if security_context.get("privileged"):
                        return True

                # Check for dangerous host access
                if spec.get("hostNetwork") or spec.get("hostPID") or spec.get("hostIPC"):
                    return True

                # Check for host path mounts
                volumes = spec.get("volumes", [])
                for volume in volumes:
                    if volume.get("hostPath"):
                        return True

        return False

    def is_exec_command(self, event: Dict[str, Any]) -> bool:
        """Detect kubectl exec commands, especially targeting system files."""
        request_uri = event.get("requestURI", "")
        if "/exec?" in request_uri and event.get("verb") == "get":
            return True
            # # Check for dangerous file access patterns
            # dangerous_patterns = [
            #     'audit-policy.yaml',
            #     '/etc/ssl/certs/',
            #     '/host/etc/',
            #     'rm%20',  # URL encoded 'rm '
            #     'cat%20'  # URL encoded 'cat '
            # ]
            #
            # for pattern in dangerous_patterns:
            #     if pattern in request_uri:
            #         return True
            #
        return False

    def is_debug_command(self, event: Dict[str, Any]) -> bool:
        """Detect kubectl debug commands creating ephemeral containers."""
        if event.get("verb") == "patch" and "/ephemeralcontainers" in event.get("requestURI", ""):

            request_obj = event.get("requestObject", {})
            ephemeral_containers = request_obj.get("spec", {}).get("ephemeralContainers", [])
            return True

            # for container in ephemeral_containers:
            #     # Check for host filesystem access patterns
            #     commands = container.get('command', [])
            #     for cmd in commands:
            #         if '/proc/1/root/' in str(cmd):
            #             return True
            #
            #     # Check for suspicious images
            #     image = container.get('image', '')
            #     if 'netshoot' in image:
            #         return True

        return False

    def is_rbac_escalation(self, event: Dict[str, Any]) -> bool:
        """Detect RBAC privilege escalation through RoleBinding creation."""
        if event.get("verb") == "create" and "rolebindings" in event.get("requestURI", ""):

            request_obj = event.get("requestObject", {})
            if request_obj.get("kind") == "RoleBinding":
                role_ref = request_obj.get("roleRef", {})

                # Check for cluster-admin escalation
                if role_ref.get("name") == "cluster-admin":
                    return True

                # # Check for suspicious RoleBinding names
                # metadata = request_obj.get("metadata", {})
                # name = metadata.get("name", "")
                # if "escalate" in name.lower():
                #     return True

        return False

    def is_secret_access(self, event: Dict[str, Any]) -> bool:
        """Detect unauthorized secret access."""
        request_uri = event.get("requestURI", "")

        # Check for secret listing/reading
        if event.get("verb") in ["list", "get"] and "/secrets" in request_uri:
            return True
            # # Particularly dangerous: kube-system secrets
            # if "kube-system" in request_uri:
            #     return True
            #
            # # Check for impersonation in secret access
            # if event.get("impersonatedUser"):
            #     return True

        return False

    def is_namespace_creation(self, event: Dict[str, Any]) -> bool:
        """Detect suspicious namespace creation."""
        if event.get("verb") == "create" and event.get("objectRef", {}).get("resource") == "namespaces":
            return True
            # # Check for suspicious namespace names
            # name = event.get("objectRef", {}).get("name", "")
            # suspicious_names = ["secure-ops", "admin", "system", "hack"]
            #
            # for suspicious in suspicious_names:
            #     if suspicious in name.lower():
            #         return True

        return False

    def is_serviceaccount_creation(self, event: Dict[str, Any]) -> bool:
        """Detect suspicious ServiceAccount creation."""
        if event.get("verb") == "create" and event.get("objectRef", {}).get("resource") == "serviceaccounts":
            return True
            # # Check for suspicious SA names
            # name = event.get("objectRef", {}).get("name", "")
            # suspicious_names = ["monitoring", "admin", "system", "escalate"]
            #
            # for suspicious in suspicious_names:
            #     if suspicious in name.lower():
            #         return True

        return False

    def is_impersonation_event(self, event: Dict[str, Any]) -> bool:
        """Detect events involving user impersonation."""
        return bool(event.get("impersonatedUser"))

    def is_authorization_check(self, event: Dict[str, Any]) -> bool:
        """Detect authorization checks (kubectl auth can-i)."""
        request_uri = event.get("requestURI", "")
        return "selfsubjectaccessreviews" in request_uri

    def is_audit_policy_tampering(self, event: Dict[str, Any]) -> bool:
        """Detect attempts to tamper with audit policy."""
        request_uri = event.get("requestURI", "")
        if "/exec?" in request_uri:
            # Look for audit-policy.yaml manipulation
            if "audit-policy.yaml" in request_uri:
                # Check for delete/remove commands
                if any(cmd in request_uri for cmd in ["rm%20", "delete", "remove"]):
                    return True
        return False

    def classify_event(self, event: Dict[str, Any]) -> List[str]:
        """Classify an event and return list of threat categories."""
        threats = []

        if self.is_privileged_pod_creation(event):
            threats.append("PRIVILEGED_POD")
            self.stats["privileged_pods"] += 1

        if self.is_exec_command(event):
            threats.append("EXEC_COMMAND")
            self.stats["exec_commands"] += 1

        if self.is_debug_command(event):
            threats.append("DEBUG_COMMAND")
            self.stats["debug_commands"] += 1

        if self.is_rbac_escalation(event):
            threats.append("RBAC_ESCALATION")
            self.stats["rbac_escalation"] += 1

        if self.is_secret_access(event):
            threats.append("SECRET_ACCESS")
            self.stats["secret_access"] += 1

        if self.is_namespace_creation(event):
            threats.append("NAMESPACE_CREATION")
            self.stats["namespace_creation"] += 1

        if self.is_serviceaccount_creation(event):
            threats.append("SERVICEACCOUNT_CREATION")

        if self.is_impersonation_event(event):
            threats.append("IMPERSONATION")
            self.stats["impersonation"] += 1

        if self.is_authorization_check(event):
            threats.append("AUTHORIZATION_CHECK")

        if self.is_audit_policy_tampering(event):
            threats.append("AUDIT_POLICY_TAMPERING")
            self.stats["audit_policy_tampering"] += 1

        return threats

    def process_event(self, event: Dict[str, Any]) -> bool:
        """Process a single audit event and determine if it's dangerous."""
        self.stats["total_events"] += 1

        threats = self.classify_event(event)

        if threats:
            self.stats["dangerous_events"] += 1

            # Add threat classification to event
            event["_threat_categories"] = threats
            event["_threat_level"] = self.get_threat_level(threats)

            self.dangerous_events.append(event)
            return True

        return False

    def get_threat_level(self, threats: List[str]) -> str:
        """Determine threat level based on threat categories."""
        critical_threats = ["PRIVILEGED_POD", "RBAC_ESCALATION", "AUDIT_POLICY_TAMPERING"]
        high_threats = ["EXEC_COMMAND", "DEBUG_COMMAND", "SECRET_ACCESS"]

        if any(threat in critical_threats for threat in threats):
            return "CRITICAL"
        elif any(threat in high_threats for threat in threats):
            return "HIGH"
        else:
            return "MEDIUM"

    def print_summary(self):
        """Print summary statistics."""
        print(f"\n🔍 AUDIT LOG SECURITY ANALYSIS SUMMARY", file=sys.stderr)
        print(f"=" * 50, file=sys.stderr)
        print(f"📊 Total events processed: {self.stats['total_events']}", file=sys.stderr)
        print(f"🚨 Dangerous events found: {self.stats['dangerous_events']}", file=sys.stderr)
        print(
            f"📈 Detection rate: {self.stats['dangerous_events']/self.stats['total_events']*100:.2f}%", file=sys.stderr
        )
        print(f"", file=sys.stderr)
        print(f"🎯 THREAT BREAKDOWN:", file=sys.stderr)
        print(f"   🔴 Privileged pods: {self.stats['privileged_pods']}", file=sys.stderr)
        print(f"   🔴 Exec commands: {self.stats['exec_commands']}", file=sys.stderr)
        print(f"   🔴 Debug commands: {self.stats['debug_commands']}", file=sys.stderr)
        print(f"   🔴 RBAC escalation: {self.stats['rbac_escalation']}", file=sys.stderr)
        print(f"   🔴 Secret access: {self.stats['secret_access']}", file=sys.stderr)
        print(f"   🔴 Namespace creation: {self.stats['namespace_creation']}", file=sys.stderr)
        print(f"   🔴 Impersonation: {self.stats['impersonation']}", file=sys.stderr)
        print(f"   🔴 Audit policy tampering: {self.stats['audit_policy_tampering']}", file=sys.stderr)


def main():
    """Main function to process audit log and filter dangerous events."""
    parser = argparse.ArgumentParser(
        description="Filter dangerous events from Kubernetes audit logs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 filter_dangerous_events.py audit_5.log
    python3 filter_dangerous_events.py audit_5.log > dangerous_events.json
    cat audit.log | python3 filter_dangerous_events.py -
        """,
    )

    parser.add_argument("audit_log", help='Path to audit log file (use "-" for stdin)')
    parser.add_argument(
        "--summary-only", "-s", action="store_true", help="Only show summary statistics, no event output"
    )
    parser.add_argument(
        "--threat-level", "-t", choices=["CRITICAL", "HIGH", "MEDIUM"], help="Filter by minimum threat level"
    )

    args = parser.parse_args()

    # Initialize filter
    event_filter = DangerousEventFilter()

    try:
        # Open input file or stdin
        if args.audit_log == "-":
            input_file = sys.stdin
        else:
            input_file = open(args.audit_log, "r", encoding="utf-8")

        # Process each line as JSON
        for line_num, line in enumerate(input_file, 1):
            line = line.strip()
            if not line:
                continue

            try:
                event = json.loads(line)
                event_filter.process_event(event)

            except json.JSONDecodeError as e:
                print(f"⚠️  JSON decode error on line {line_num}: {e}", file=sys.stderr)
                continue

        # Close file if not stdin
        if args.audit_log != "-":
            input_file.close()

        # Filter by threat level if specified
        filtered_events = event_filter.dangerous_events
        if args.threat_level:
            filtered_events = [
                event
                for event in filtered_events
                if event["_threat_level"] == args.threat_level
                or (args.threat_level == "HIGH" and event["_threat_level"] == "CRITICAL")
                or (args.threat_level == "MEDIUM" and event["_threat_level"] in ["HIGH", "CRITICAL"])
            ]

        # Output results
        if not args.summary_only:
            for event in filtered_events:
                print(json.dumps(event, separators=(",", ":")))

        # Print summary to stderr
        event_filter.print_summary()

        if filtered_events:
            print(f"\n🎯 Found {len(filtered_events)} dangerous events!", file=sys.stderr)
            if args.threat_level:
                print(f"   (filtered by threat level: {args.threat_level})", file=sys.stderr)
        else:
            print(f"\n✅ No dangerous events detected.", file=sys.stderr)

    except FileNotFoundError:
        print(f"❌ Error: File '{args.audit_log}' not found.", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print(f"\n⚠️  Processing interrupted by user.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
