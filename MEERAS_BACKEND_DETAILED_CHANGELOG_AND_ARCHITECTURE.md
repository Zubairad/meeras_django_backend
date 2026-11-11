# Meeras (مِیراث) — Backend Architectural Overhaul, Module Implementations & Redundancy Audit Report

**Author / Team**: Zubair Ahmad (Group Leader), Sahibzadi Manal Zahra  
**Supervisor**: Sir Abdul Karim Shahid  
**Department**: Computer Science, COMSATS University Islamabad, Lahore Campus  
**Project**: Meeras (مِیراث) — Smart Disaster Management Platform  

---

## 1. Executive Summary & Context

This document explains all architectural enhancements, security upgrades, database schema expansions, redundancy eliminations, and AI/routing integrations applied to the **Meeras Django Backend**.

The primary objective was to align the operational backend codebase directly with the **Meeras Final Year Project Proposal / Mid-Report (Session 2023–2027)**, fulfilling functional requirements across emergency response, resource management, and risk routing while ensuring production-grade code quality.

---

## 2. Complete Database Schema Overhaul ([`core/models.py`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/models.py))

The database schema was completely overhauled to match your proposal's **Entity-Relationship Diagram (Figure 3.39)** and **Class Diagram (Figure 3.38)**:

| Model Name | Key Fields Added / Updated | Related Proposal Requirements | Purpose in Disaster Management |
|---|---|---|---|
| **`User`** | `role` (`citizen`, `helper`, `ngo_admin`, `system_admin`), `organization_name`, `is_verified_ngo`, `is_blocked`, `phone` | FR 1.1–1.3, FR 9.1–9.6, FR 10.2, FR 10.5 | Prevents unauthorized self-assignment of administrator roles. Forces newly registered NGOs to remain unverified until approved by a system administrator. Enables immediate suspension of abusive accounts. |
| **`DisasterZone`** *(New)* | `name`, `disaster_type`, `risk_level` (`Low`, `Medium`, `High`, `Critical`), `latitude`, `longitude`, `radius_km`, `reported_rainfall_mm`, `is_active` | FR 2.2, FR 8.1, FR 12.1, Fig 3.39 | Represents active flooding and hazard perimeters. Used by the map heatmap view and queried dynamically by the routing engine to prune impassable roads. |
| **`Shelter`** *(New)* | `name`, `location_name`, `latitude`, `longitude`, `capacity`, `current_occupancy`, `status` (`Open`, `Full`, `Closed`), `contact_number`, `managed_by` | FR 2.3, Fig 3.38, Fig 3.39 | Represents emergency relief centers and camps. Tracks available capacity (`available_beds = capacity - current_occupancy`) for safe evacuation routing. |
| **`HelpRequest`** | `title`, `description`, `location`, `latitude`, `longitude`, `urgency` (1–5), `status` (`pending`, `assigned`, `completed`, `cancelled`), `people_affected`, `assigned_to`, `created_by`, `resolved_at` | FR 5.1–5.7, Fig 3.39 | Core crisis ticket model. Includes GPS coordinates for map pin rendering and proximity routing. Protected by atomic concurrency locking to prevent multiple helpers from accepting the same request simultaneously. |
| **`Inventory`** | `ngo`, `item_name`, `category` (`Food`, `Water`, `Medical`, `Shelter`, `Sanitation`), `quantity`, `low_stock_threshold`, `unit` | FR 7.1–7.5, Fig 3.39 | Multi-tenant inventory tracking per NGO. Includes threshold alerts and category tagging. |
| **`InventoryLog`** *(New)* | `item`, `change_quantity`, `balance_after`, `reason`, `logged_by`, `timestamp` | FR 7.4, Fig 3.39 | Audit ledger recording every stock distribution to relief camps and restocking operation. |
| **`Personnel`** | `ngo`, `name`, `role`, `contact_number`, `available`, `assigned_request` | FR 6.1–6.5, Fig 3.38, Fig 3.39 | Field responder roster. Links personnel members directly to specific help requests and tracks active deployment availability. |
| **`Broadcast`** | `posted_by`, `message`, `location`, `latitude`, `longitude`, `status` (`verified`, `flagged`, `pending`), `flag_count`, `flag_reason`, `is_urgent`, `attachment` | FR 3.1–3.5, UC 4.1–4.2 | Community feed. Supports user flagging of false rumors and administrator moderation matching your prototype UI screenshots. |
| **`ChatMessage`** | `sender`, `message`, `timestamp`, `is_flagged` | FR 4.1–4.5, Fig 3.39 | Real-time communication log with immutable history. |
| **`AuditLog`** *(New)* | `actor`, `action`, `target_model`, `target_id`, `details`, `timestamp` | FR 10.4, NFR 10 | Immutable system audit trail tracking administrative interventions, approvals, and user suspensions. |

---

## 3. Redundant & Duplicate Code Elimination (DRY Audit)

### 1. ViewSet Scoping & NGO User Injection
* **Before**: [`InventoryViewSet`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/views.py) and [`PersonnelViewSet`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/views.py) contained identical copy-pasted `get_queryset()` methods. Furthermore, callers were required to manually specify `ngo: <id>` in POST payloads, risking cross-NGO data pollution.
* **After**: Created a unified [`NGORelatedViewSet`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/views.py#L29) base class that automatically handles role-scoped queries (NGO admins see only their items; helpers and citizens view all) and automatically assigns `ngo = request.user` via `perform_create()`.

### 2. Elimination of Duplicate Serializer Validators
* **Before**: [`serializers.py`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/serializers.py) explicitly re-implemented `validate_urgency` and `validate_quantity` using custom `if` statements, duplicating `MinValueValidator` and `MaxValueValidator` already defined on the models.
* **After**: Removed redundant serializer methods. DRF's `ModelSerializer` now inspects the model validators natively.

### 3. Elimination of In-Memory `low_stock` Loops
* **Before**: The `low_stock` endpoint fetched all inventory records into Python memory and iterated over an `@property`.
* **After**: Optimized to run directly at the database level:
  ```python
  qs = self.get_queryset().filter(quantity__lte=models.F('low_stock_threshold'))
  ```

### 4. Streamlined Permissions
* **Before**: `BroadcastViewSet` declared permissions at the class level and then redundantly overrode `get_permissions()`.
* **After**: Centralized object-level and action-level authorization into clean, reusable permissions ([`core/permissions.py`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/permissions.py)).

---

## 4. Security Hardening & Concurrency Safeguards

### 1. Race Condition Prevention on Help Request Assignment
* **Problem**: In a real disaster, multiple helpers may tap "Accept" on the same urgent rescue request simultaneously. Without concurrency locks, both helpers could claim the same ticket.
* **Solution**: In [`HelpRequestViewSet.assign`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/views.py#L112-L149), the request is enclosed within `transaction.atomic()` and queries the row using `select_for_update()`. If the ticket has already been assigned, the second request immediately receives an **HTTP 409 Conflict** (`alt [Already assigned]` from Figure 3.30).

### 2. Privilege Escalation Prevention on Signup
* **Problem**: Public user registration allowed clients to pass `"role": "system_admin"`, granting full platform control to anyone.
* **Solution**: [`UserRegistrationSerializer.validate_role`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/serializers.py#L25-L29) rejects `system_admin`. Public signups can only select `citizen` or `helper`. If an applicant selects `ngo_admin`, their account is automatically created with `is_verified_ngo = False`, requiring admin approval before they can deploy personnel or manage resources.

### 3. Immediate Account Suspension
* **Implementation**: The [`IsActiveAndUnblocked`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/permissions.py#L9-L13) permission class verifies the user's `is_blocked` status on every API request. If an admin blocks a user, their JWT access is invalidated immediately.

---

## 5. AI Disaster Risk Prediction Engine ([`core/ai_service.py`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/ai_service.py))

* **Input Features**: Station, Month, TXTX (Max Temp °C), TNTN (Min Temp °C), Diurnal Temp Range, RRR (Rainfall mm), and Monsoon Seasonality (July–September).
* **Crowdsourced Text NLP**: Scans citizen reports for high-risk disaster keywords (`"dam breach"`, `"water rising rapidly"`, `"submerged"`, `"landslide"`).
* **Machine Learning Pipeline**: Scikit-Learn `ColumnTransformer` with `OneHotEncoder` and a `RandomForestClassifier` (100 estimators, max depth 6).
* **Failure Detection & Fallback Mechanism**:
  If the model file (`pmd_disaster_model.pkl`) is missing, corrupted, or encounters unexpected input dimensions, the system logs a warning and automatically falls back to **NDMA hydrological threshold heuristics** ($\ge 150\text{ mm}$ rain $\to$ Critical Risk, $\ge 75\text{ mm}$ $\to$ High Risk). This ensures the API remains functional under all failure conditions.

---

## 6. Disaster-Aware Safe Routing Engine ([`core/routing_service.py`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/routing_service.py))

* **Algorithm**: Dijkstra / $A^*$ algorithm with dynamic edge weighting.
* **Hazard Avoidance**: Road segments passing through or near active `DisasterZone` records (such as Indus riverine flood zones) have their edge costs dynamically scaled. Critical risk zones set the edge weight to $\infty$ (impassable).
* **Verification Example**:
  When travelling from **Sukkur to Multan** during extreme monsoon flooding at Rahim Yar Khan (258.2 mm rain), the direct N-5 route ($420\text{ km}$) is blocked. The routing engine automatically diverts traffic through the **Cholistan Desert Corridor and Bahawalpur** ($440\text{ km}$) along dry, safe roads.
* **FR 8.6 Least-Risk Fallback**:
  If all routes are cut off by flood waters, the engine re-runs Dijkstra in emergency mode to find the **least-risk alternative route** and attaches a `hazard_warning: true` banner.

---

## 7. Enhanced Django Admin Command Portal ([`core/admin.py`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/admin.py))

1. **Branded Header**: *Meeras (مِیراث) — Disaster Management Administration*.
2. **Visual Badges**:
   * Color-coded urgency badges (Level 1 Green to Level 5 Critical Crimson).
   * Shelter occupancy progress bars showing live percentage capacity.
   * `LOW STOCK` alerts on inventory items below safety thresholds.
   * Status indicators for broadcasts (`Verified`, `Flagged`, `Pending Review`).
3. **One-Click Bulk Actions**:
   * *✔ Approve selected NGO organizations*
   * *⛔ Block selected user accounts*
   * *✔ Verify selected broadcasts (publish to public verified feed)*
   * *🚩 Flag selected broadcasts as Misinformation*
   * *🚨 Escalate selected requests to Level 5 (Critical)*
   * *✅ Deactivate selected disaster zones (All Clear)*
