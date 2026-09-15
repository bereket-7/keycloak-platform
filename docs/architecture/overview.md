# Architecture Overview

## Purpose

The Keycloak Platform is a reusable centralized identity platform
that can provide authentication and identity services to multiple
independent applications.

## High-Level Architecture

```text
                         Internet
                            |
                            v
                    +---------------+
                    | Reverse Proxy |
                    | Nginx/Traefik |
                    +-------+-------+
                            |
                            | HTTPS
                            v
                    +---------------+
                    |   Keycloak    |
                    |               |
                    | OAuth2 / OIDC |
                    | Identity      |
                    | Authentication|
                    +-------+-------+
                            |
                            |
                            v
                    +---------------+
                    |  PostgreSQL   |
                    |               |
                    | Keycloak DB   |
                    +---------------+

                         Keycloak
                            |
              +-------------+-------------+
              |             |             |
              v             v             v
          Project A     Project B     Project C
          Frontend      Frontend      Mobile
          Backend       Backend       Backend