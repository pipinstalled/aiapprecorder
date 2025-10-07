#!/usr/bin/env python3
"""
Simple script to run the FastAPI Persian Speech-to-Text service
"""

import sys

import uvicorn


def main():
    """Run the FastAPI application"""

    # Configuration
    host = "0.0.0.0"
    port = 8000
    reload = True
    log_level = "info"

    # Check if running in production mode
    if len(sys.argv) > 1 and sys.argv[1] == "production":
        reload = False
        log_level = "warning"
        print("Running in production mode...")

    print(f"Starting Persian Speech-to-Text API on {host}:{port}")
    print(f"Interactive docs will be available at: http://{host}:{port}/docs")

    # Run the application
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=reload,
        log_level=log_level,
        access_log=True,
    )


if __name__ == "__main__":
    main()
