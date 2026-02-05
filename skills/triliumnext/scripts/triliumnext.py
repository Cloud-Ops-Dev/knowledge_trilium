#!/usr/bin/env python3
"""TriliumNext knowledge base integration for OpenClaw.

This script provides CLI access to TriliumNext ETAPI for note management.
"""

import argparse
import json
import os
import sys
from typing import Any, NoReturn


# =============================================================================
# Environment Validation
# =============================================================================

REQUIRED_ENV_VARS = ["TRILIUM_BASE_URL", "TRILIUM_API_TOKEN"]


def validate_environment() -> dict[str, str]:
    """Validate required environment variables are set.

    Returns:
        Dictionary of environment variable names to values.

    Exits with code 2 if any required variables are missing.
    """
    missing = [var for var in REQUIRED_ENV_VARS if not os.environ.get(var)]

    if missing:
        print(
            f"Error: Missing required environment variables: {', '.join(missing)}\n\n"
            "Please set the following environment variables:\n"
            "  TRILIUM_BASE_URL  - Base URL of the TriliumNext server (e.g., http://localhost:8080)\n"
            "  TRILIUM_API_TOKEN - ETAPI authentication token\n\n"
            "Example:\n"
            "  export TRILIUM_BASE_URL='http://localhost:8080'\n"
            "  export TRILIUM_API_TOKEN='your-token-here'",
            file=sys.stderr
        )
        sys.exit(2)

    return {var: os.environ[var] for var in REQUIRED_ENV_VARS}


# =============================================================================
# ETAPI Client (Placeholder)
# =============================================================================

class TriliumClient:
    """Placeholder ETAPI client for TriliumNext.

    All methods raise NotImplementedError until ETAPI integration is complete.
    """

    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url.rstrip("/")
        self.api_token = api_token

    def ping(self) -> dict[str, Any]:
        """Test connectivity to TriliumNext server."""
        raise NotImplementedError("ETAPI ping not yet implemented")

    def create_note(
        self,
        title: str,
        content: str,
        parent_id: str | None = None
    ) -> dict[str, Any]:
        """Create a new note."""
        raise NotImplementedError("ETAPI note creation not yet implemented")

    def get_note(self, note_id: str) -> dict[str, Any]:
        """Retrieve a note by ID."""
        raise NotImplementedError("ETAPI note retrieval not yet implemented")

    def update_note(
        self,
        note_id: str,
        title: str | None = None,
        content: str | None = None
    ) -> dict[str, Any]:
        """Update an existing note."""
        raise NotImplementedError("ETAPI note update not yet implemented")

    def search_notes(self, query: str) -> list[dict[str, Any]]:
        """Search for notes."""
        raise NotImplementedError("ETAPI note search not yet implemented")


# =============================================================================
# Output Helpers
# =============================================================================

def output_result(data: Any, json_mode: bool) -> None:
    """Output result in appropriate format."""
    if json_mode:
        print(json.dumps(data))
    else:
        if isinstance(data, dict):
            for key, value in data.items():
                print(f"{key}: {value}")
        elif isinstance(data, list):
            for item in data:
                print(item)
        else:
            print(data)


def output_error(message: str, json_mode: bool) -> NoReturn:
    """Output error message and exit with code 1."""
    if json_mode:
        print(json.dumps({"error": message}))
    else:
        print(f"Error: {message}", file=sys.stderr)
    sys.exit(1)


# =============================================================================
# Command Handlers
# =============================================================================

def cmd_ping(args: argparse.Namespace, client: TriliumClient) -> None:
    """Handle ping command."""
    try:
        result = client.ping()
        output_result(result, args.json)
    except NotImplementedError as e:
        output_error(str(e), args.json)


def cmd_note_create(args: argparse.Namespace, client: TriliumClient) -> None:
    """Handle note create command."""
    try:
        result = client.create_note(
            title=args.title,
            content=args.content,
            parent_id=args.parent_id
        )
        output_result(result, args.json)
    except NotImplementedError as e:
        output_error(str(e), args.json)


def cmd_note_get(args: argparse.Namespace, client: TriliumClient) -> None:
    """Handle note get command."""
    try:
        result = client.get_note(args.note_id)
        output_result(result, args.json)
    except NotImplementedError as e:
        output_error(str(e), args.json)


def cmd_note_update(args: argparse.Namespace, client: TriliumClient) -> None:
    """Handle note update command."""
    try:
        result = client.update_note(
            note_id=args.note_id,
            title=args.title,
            content=args.content
        )
        output_result(result, args.json)
    except NotImplementedError as e:
        output_error(str(e), args.json)


def cmd_note_search(args: argparse.Namespace, client: TriliumClient) -> None:
    """Handle note search command."""
    try:
        result = client.search_notes(args.query)
        output_result(result, args.json)
    except NotImplementedError as e:
        output_error(str(e), args.json)


# =============================================================================
# CLI Setup
# =============================================================================

def create_parser() -> argparse.ArgumentParser:
    """Create argument parser with all subcommands."""
    parser = argparse.ArgumentParser(
        prog="triliumnext",
        description="TriliumNext knowledge base integration for OpenClaw"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON"
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # ping command
    subparsers.add_parser("ping", help="Test connectivity to TriliumNext server")

    # note subcommand with its own subparsers
    note_parser = subparsers.add_parser("note", help="Note operations")
    note_subparsers = note_parser.add_subparsers(dest="note_command", help="Note commands")

    # note create
    note_create = note_subparsers.add_parser("create", help="Create a new note")
    note_create.add_argument("--title", required=True, help="Note title")
    note_create.add_argument("--content", required=True, help="Note content")
    note_create.add_argument("--parent-id", dest="parent_id", help="Parent note ID")

    # note get
    note_get = note_subparsers.add_parser("get", help="Retrieve a note by ID")
    note_get.add_argument("note_id", help="Note ID to retrieve")

    # note update
    note_update = note_subparsers.add_parser("update", help="Update an existing note")
    note_update.add_argument("note_id", help="Note ID to update")
    note_update.add_argument("--title", help="New note title")
    note_update.add_argument("--content", help="New note content")

    # note search
    note_search = note_subparsers.add_parser("search", help="Search for notes")
    note_search.add_argument("query", help="Search query")

    return parser


def main() -> None:
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args()

    # Show help if no command provided
    if not args.command:
        parser.print_help()
        sys.exit(0)

    # Validate environment before proceeding with any command
    env = validate_environment()

    # Create client
    client = TriliumClient(
        base_url=env["TRILIUM_BASE_URL"],
        api_token=env["TRILIUM_API_TOKEN"]
    )

    # Route to appropriate handler
    if args.command == "ping":
        cmd_ping(args, client)
    elif args.command == "note":
        if not args.note_command:
            parser.parse_args(["note", "--help"])
        elif args.note_command == "create":
            cmd_note_create(args, client)
        elif args.note_command == "get":
            cmd_note_get(args, client)
        elif args.note_command == "update":
            cmd_note_update(args, client)
        elif args.note_command == "search":
            cmd_note_search(args, client)


if __name__ == "__main__":
    main()
