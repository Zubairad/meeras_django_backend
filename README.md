# Meeras Django Backend

A REST API backend for the Meeras NGO coordination platform.

## Setup

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # edit as needed
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DJANGO_SECRET_KEY` | (dev key) | Secret key — **change in production** |
| `DEBUG` | `True` | Set to `False` in production |
| `ALLOWED_HOSTS` | `[]` | Comma-separated hostnames |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000` | Comma-separated origins |

## API Endpoints

| Method | URL | Description |
|---|---|---|
| POST | `/api/token/` | Obtain JWT access + refresh tokens |
| POST | `/api/token/refresh/` | Refresh access token |
| POST | `/api/token/verify/` | Verify token validity |
| GET/POST | `/api/users/` | List or register users |
| GET | `/api/users/me/` | Authenticated user's profile |
| GET/POST | `/api/help-requests/` | List or create help requests |
| PATCH | `/api/help-requests/{id}/assign/` | Assign a helper (NGO admin only) |
| PATCH | `/api/help-requests/{id}/complete/` | Mark as completed |
| GET/POST | `/api/inventory/` | Manage inventory items |
| GET | `/api/inventory/low_stock/` | Items below threshold |
| GET/POST | `/api/personnel/` | Manage personnel |
| GET/POST | `/api/broadcasts/` | Community broadcasts |
| GET/POST | `/api/chat/` | Chat messages (no edit/delete) |

## Roles

- `ngo_admin` — manages inventory, personnel, and assigns help requests
- `helper` — can be assigned to help requests
- `system_admin` — platform-level administration
