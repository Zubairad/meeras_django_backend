# Meeras (مِیراث) — Django REST Backend

A disaster response, crisis coordination, and risk prediction backend built with **Django REST Framework**, **Scikit-Learn**, and **PostgreSQL/SQLite** for the Meeras Emergency Management Platform.

---

## 📌 Overview

Meeras coordinates humanitarian relief operations between affected citizens (victims), volunteer responders (helpers), non-governmental organizations (NGOs), and government authorities during climate catastrophes (monsoon floods, flash floods, and cloudbursts).

### Core Features

1. **Role-Based Authentication & Verification**:
   - Secure JWT authentication (`access` & `refresh` tokens with automated rotation).
   - Multi-tier roles: `citizen` (victim), `helper` (volunteer), `ngo_admin` (NGO coordinator), and `system_admin` (platform authority).
   - Privilege escalation safeguards: Public signup restricted to `citizen` and `helper`. NGO accounts require administrator verification (`is_verified_ngo = False` until approved).
   - Immediate suspension via `is_blocked` flag with automatic session rejection.

2. **Emergency Help Requests (Crisis Tickets)**:
   - Submission with GPS coordinates (`latitude`, `longitude`), urgency rating (1 to 5), and headcount.
   - Atomic concurrency locking (`select_for_update()`) preventing race conditions when multiple helpers accept the same ticket simultaneously (returns `409 Conflict` if already assigned).
   - Controlled resolution workflows restricted to assigned responders or ticket creators.

3. **Disaster-Aware Safe Routing Engine (Dijkstra / A*)**:
   - Computes safe evacuation paths between regional corridors (e.g. Sukkur, R.Y. Khan, Multan, D.G. Khan, Nowshera).
   - Intersects route corridors with active `DisasterZone` polygons, applying dynamic risk penalties or setting edge weights to $\infty$ for critical hazard zones.
   - **FR 8.6 Fallback Mode**: If all paths are cut off, automatically computes the *least-risk alternative route* and attaches a prominent hazard warning.

4. **AI Disaster & Flood Risk Prediction**:
   - Grounded in official **Pakistan Meteorological Department (PMD)** climate archives (`TXTX` Max Temp, `TNTN` Min Temp, `RRR` Monthly Rainfall).
   - Scikit-Learn `RandomForestClassifier` pipeline predicting risk probabilities ($P \in [0.0, 1.0]$) and tiers (`Low`, `Medium`, `High`, `Critical`).
   - **Failure Detection & Heuristic Fallback**: Gracefully detects missing or corrupt model files and seamlessly switches to NDMA hydrological threshold heuristics without interrupting service.

5. **Community Broadcasts & Misinformation Moderation**:
   - Community situational feed with status filtering (`all`, `verified`, `flagged`, `pending`).
   - Crowdsourced flagging mechanism: Posts flagged by 3 or more users are automatically escalated to the admin review queue.
   - Administrative moderation actions (`verify`, `unflag`) matching prototype workflows.

6. **NGO Resource & Personnel Management**:
   - Multi-tenant inventory tracking with category filtering (`Food`, `Water`, `Medical`, `Shelter`, `Sanitation`).
   - Automatic usage audit logs (`InventoryLog`) recording all distributed deductions and restocks.
   - Optimized database-level low-stock threshold queries (`quantity__lte=F('low_stock_threshold')`).
   - Personnel roster with availability toggling and direct assignment to emergency help requests.

7. **Enhanced Django Admin Command Portal**:
   - Branded command interface (`/admin/`) with color-coded urgency and risk badges.
   - Bulk administrative actions for one-click NGO approval, user account suspension, disaster zone activation, and broadcast moderation.
   - Immutable system audit trail (`AuditLog`).

---

## 🛠 Tech Stack

* **Language**: Python 3.14 / 3.11+
* **Web Framework**: Django 6.0+ & Django REST Framework 3.17+
* **Authentication**: SimpleJWT 5.5+
* **Machine Learning**: Scikit-Learn 1.9+, Pandas 3.1+, NumPy 2.5+, Joblib 1.6+
* **Database**: SQLite (local development default) / PostgreSQL (production-ready via environment configuration)
* **CORS & Filtering**: `django-cors-headers`, `django-filter`

---

## 🚀 Setup & Installation

### 1. Clone & Create Virtual Environment
```bash
cd meeras_django_backend_improved
python -m venv .venv

# On Windows:
.\.venv\Scripts\activate

# On Linux / macOS:
source .venv/bin/activate
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Configure Environment Variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Key configurations inside `.env`:
```env
DJANGO_SECRET_KEY=your-secure-production-key
DEBUG=True
ALLOWED_HOSTS=*
CORS_ALLOWED_ORIGINS=http://localhost:3000

# Optional PostgreSQL Configuration (defaults to SQLite if omitted):
# POSTGRES_DB=meeras_db
# POSTGRES_USER=postgres
# POSTGRES_PASSWORD=your_password
# POSTGRES_HOST=localhost
# POSTGRES_PORT=5432
```

### 4. Apply Database Migrations
```bash
python manage.py migrate
```

### 5. Create Superuser (Admin Command Access)
```bash
python manage.py createsuperuser
```

### 6. Run the Development Server
```bash
python manage.py runserver 0.0.0.0:8000
```
* **REST API Root**: `http://127.0.0.1:8000/api/`
* **Admin Portal**: `http://127.0.0.1:8000/admin/`

---

## 📡 API Reference

### Authentication Endpoints
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/token/` | Obtain JWT access + refresh tokens | No |
| `POST` | `/api/token/refresh/` | Refresh expired access token | No |
| `POST` | `/api/token/verify/` | Validate token authenticity | No |
| `POST` | `/api/users/` | Register citizen / helper / NGO admin | No |
| `GET` | `/api/users/me/` | Authenticated user profile | Yes |
| `POST` | `/api/users/{id}/verify_ngo/` | Admin action: Approve NGO account | System Admin |
| `POST` | `/api/users/{id}/block_user/` | Admin action: Suspend/block user | System Admin |

### Emergency Help Requests
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/help-requests/` | List help requests (filterable by status, urgency) | Yes |
| `POST` | `/api/help-requests/` | Submit crisis request with GPS coordinates | Yes |
| `PATCH` | `/api/help-requests/{id}/assign/` | Accept or assign request (atomic lock protected) | Yes |
| `PATCH` | `/api/help-requests/{id}/complete/` | Mark request resolved | Assigned / Creator |
| `PATCH` | `/api/help-requests/{id}/cancel/` | Cancel open request | Creator / Admin |

### Disaster-Aware Routing & AI Prediction
| Method | Endpoint | Description | Payload Example |
|---|---|---|---|
| `POST` | `/api/routes/safe-route/` | Calculates safe route avoiding active hazard zones | `{"start": "SUKKUR", "destination": "MULTAN"}` |
| `POST` | `/api/predict-risk/` | Evaluates weather metrics through PMD AI model | `{"station": "R.Y.KHAN", "month": 8, "rainfall_mm": 258.2}` |

### Inventory & Personnel
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/inventory/` | List NGO inventory items | Yes |
| `POST` | `/api/inventory/` | Add inventory item (auto-linked to NGO) | Verified NGO Admin |
| `GET` | `/api/inventory/low_stock/` | Filter items below threshold (DB optimized) | Yes |
| `POST` | `/api/inventory/{id}/adjust_stock/` | Record distribution/restock + audit log | Verified NGO Admin |
| `POST` | `/api/personnel/{id}/assign_to_request/` | Deploy personnel to HelpRequest | Verified NGO Admin |
| `POST` | `/api/personnel/{id}/release/` | Free deployed personnel back to roster | Verified NGO Admin |

### Broadcasts & Community Moderation
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/broadcasts/` | Public situational updates feed | Yes |
| `POST` | `/api/broadcasts/` | Submit broadcast update | Yes |
| `POST` | `/api/broadcasts/{id}/flag/` | Flag post as false or panic-inducing | Yes |
| `POST` | `/api/broadcasts/{id}/verify/` | Approve flagged post to verified feed | System Admin |
| `POST` | `/api/broadcasts/{id}/unflag/` | Dismiss flags and reset post | System Admin |

---

## 🧪 Running Automated Tests

Run the complete 11-test suite verifying authentication, atomic concurrency, Dijkstra routing, AI prediction, and moderation workflows:

```bash
python manage.py test core
```

Expected output:
```
Creating test database for alias 'default'...
...........
----------------------------------------------------------------------
Ran 11 tests in 117.550s

OK
Destroying test database for alias 'default'...
```
