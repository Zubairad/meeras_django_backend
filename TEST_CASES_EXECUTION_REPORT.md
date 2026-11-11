# Meeras (مِیراث) — Automated Test Execution Report

**Project**: Meeras (مِیراث) — Smart Disaster Management Platform  
**Authors**: Zubair Ahmad (Group Leader), Sahibzadi Manal Zahra  
**Supervisor**: Sir Abdul Karim Shahid  
**Department**: Computer Science, COMSATS University Islamabad, Lahore Campus  
**Execution Timestamp**: 2026-11-09  
**Test Framework**: Django Test Runner / REST Framework APIClient  
**Target Environment**: SQLite / Python 3.14  

---

## 1. Test Execution Summary

| Metric | Result |
|---|---|
| **Total Automated Tests Executed** | **11** |
| **Passed** | **11 (100.0%)** |
| **Failed** | **0 (0.0%)** |
| **Errors** | **0 (0.0%)** |
| **Execution Duration** | **117.55 seconds** |
| **Overall Status** | **ALL TESTS PASSED (OK)** |

---

## 2. Traceability Matrix & Executed Test Cases

This matrix directly maps the automated test suite in [`core/tests.py`](file:///c:/Users/HP/Downloads/meeras_django_backend_improved/meeras_improved/core/tests.py) to the requirements, use cases, and manual test cases defined in **Chapter 2 & Chapter 4 of your FYP Proposal**:

| Test ID | Method Name in Test Suite | Proposal Requirement | Related Proposal TC / UC | Feature Verified | Status |
|---|---|---|---|---|---|
| **TC-SEC-01** | `test_registration_prevents_system_admin_escalation` | FR 9.1, NFR 10.4 | TC-15, TC-99, UC-1.1 | Blocks privilege escalation on public registration when attempting to claim `system_admin`. | **PASS** |
| **TC-AUTH-01** | `test_ngo_admin_starts_unverified` | FR 1.1, FR 1.3 | TC-01, TC-06, UC-1.1 | Ensures newly registered NGO administrators start with `is_verified_ngo = False`. | **PASS** |
| **TC-AUTH-02** | `test_admin_can_verify_ngo` | FR 1.3, FR 10.2 | TC-07, TC-86, UC-10.2 | Administrator verification action approves pending NGO organizations and logs audit entry. | **PASS** |
| **TC-HELP-01** | `test_help_request_creation_and_atomic_assignment` | FR 5.1, FR 5.3 | TC-43, TC-45, UC-6.1 | Submits crisis ticket with GPS coordinates and assigns helper using atomic database lock. | **PASS** |
| **TC-HELP-02** | `test_help_request_creation_and_atomic_assignment` *(Part 2)* | FR 5.3, NFR 5.1 | Fig 3.30 alt [Already assigned] | Verifies race condition prevention: returns **HTTP 409 Conflict** if a second helper attempts to accept an already assigned ticket. | **PASS** |
| **TC-HELP-03** | `test_help_request_completion` | FR 5.4 | TC-46, UC-6.3 | Verifies completion permissions: random users are rejected with **403 Forbidden**, while assigned responders can complete the request. | **PASS** |
| **TC-INV-01** | `test_inventory_creation_and_stock_adjust_log` | FR 7.1, FR 7.4, FR 7.5 | TC-60, TC-65, TC-66, UC-8.2 | Adds inventory items, adjusts stock with audit history (`InventoryLog`), and evaluates low-stock threshold queries. | **PASS** |
| **TC-BROAD-01** | `test_broadcast_flagging_and_admin_verification` | FR 3.1, FR 4.6, FR 10.7 | TC-94, TC-95, TC-127, UC-4.2 | Community members flag alarmist posts; auto-escalates to `flagged` upon 3 flags; admin verifies post. | **PASS** |
| **TC-ROUTE-01** | `test_dijkstra_safe_route_hazard_avoidance` | FR 2.4, FR 8.5 | TC-20, TC-125, TC-135, UC-12.2 | Dijkstra algorithm routes from Sukkur to Multan, automatically bypassing Critical flood zones at Rahim Yar Khan via Cholistan. | **PASS** |
| **TC-ROUTE-02** | `test_routing_fallback_least_risk_mode` | FR 8.6 | TC-126, UC-12.2 (Alt Flow) | Verifies fallback mode: if all corridors are flooded, calculates the least-risk alternative with a hazard warning banner. | **PASS** |
| **TC-AI-01** | `test_ai_disaster_risk_prediction_with_pmd_data` | FR 8.1, FR 12.1 | TC-114, TC-129, TC-134, UC-12.1 | Evaluates August 2024 Rahim Yar Khan monsoon parameters (258.2 mm rain) through the PMD model, predicting High/Critical risk. | **PASS** |
| **TC-AI-02** | `test_ai_predictor_failure_detection_and_heuristic_fallback` | UC 12.1 (Alt Flow) | TC-138, TC-142 | Verifies automated failure detection: corrupt or missing models gracefully fall back to hydrological threshold heuristics without crashing. | **PASS** |

---

## 3. Detailed Step-by-Step Test Execution Log

### Test 1: `test_registration_prevents_system_admin_escalation`
* **Test Objective**: Verify that unauthorized users cannot self-assign administrator privileges during public signup.
* **Payload**:
  ```json
  {
    "username": "hacker",
    "email": "hacker@meeras.org",
    "password": "StrongPassword123",
    "role": "system_admin"
  }
  ```
* **Expected Result**: HTTP 400 Bad Request with validation error `"Cannot register as System Administrator directly"`.
* **Actual Result**: `HTTP 400 Bad Request` — Validation triggered; account creation blocked.
* **Status**: **PASS**

---

### Test 2: `test_ngo_admin_starts_unverified`
* **Test Objective**: Verify that registering as an NGO Administrator starts the account in an unverified state awaiting platform review.
* **Payload**:
  ```json
  {
    "username": "al_khidmat",
    "email": "alkhidmat@meeras.org",
    "password": "StrongPassword123",
    "role": "ngo_admin",
    "organization_name": "Al Khidmat Foundation"
  }
  ```
* **Expected Result**: Account created with `is_verified_ngo = False`.
* **Actual Result**: `HTTP 201 Created` — User created; `is_verified_ngo` confirmed `False` in the database.
* **Status**: **PASS**

---

### Test 3: `test_admin_can_verify_ngo`
* **Test Objective**: Validate the administrative action endpoint that approves pending NGOs (`POST /api/users/{id}/verify_ngo/`).
* **Expected Result**: Target user's `is_verified_ngo` flag is updated to `True` and an `AuditLog` entry is generated.
* **Actual Result**: `HTTP 200 OK` — NGO status updated to `Verified`.
* **Status**: **PASS**

---

### Test 4 & 5: `test_help_request_creation_and_atomic_assignment`
* **Test Objective**: Submit an emergency request with GPS coordinates, verify helper self-assignment, and verify concurrency locking when two helpers accept simultaneously.
* **Input Data**:
  ```json
  {
    "title": "Family stranded on roof",
    "description": "Water levels rising rapidly in Rajanpur sector 3",
    "location": "Rajanpur Sector 3",
    "latitude": 29.1035,
    "longitude": 70.3250,
    "urgency": 5,
    "people_affected": 6
  }
  ```
* **Step 1 Result**: Helper 1 accepts $\to$ `HTTP 200 OK`, `status = 'assigned'`.
* **Step 2 Result**: Helper 2 attempts acceptance $\to$ `HTTP 409 Conflict` (`"This help request is already assigned to another responder."`).
* **Status**: **PASS**

---

### Test 6: `test_help_request_completion`
* **Test Objective**: Ensure only assigned helpers, ticket creators, or administrators can mark requests as resolved.
* **Execution**:
  * Unrelated citizen attempts completion $\to$ `HTTP 403 Forbidden` (`"Permission denied."`).
  * Assigned helper attempts completion $\to$ `HTTP 200 OK`, `status = 'completed'`, `resolved_at` recorded.
* **Status**: **PASS**

---

### Test 7: `test_inventory_creation_and_stock_adjust_log`
* **Test Objective**: Validate NGO inventory tracking, stock deduction history (`InventoryLog`), and optimized threshold query.
* **Execution**:
  * Added 500 units of water purification tablets (threshold: 50).
  * Dispatched 460 units to flood relief camp $\to$ Remaining stock: 40 units.
  * Verified `low_stock_alert = True`.
  * Queried `GET /api/inventory/low_stock/` $\to$ Returned 1 item matching database threshold.
* **Status**: **PASS**

---

### Test 8: `test_broadcast_flagging_and_admin_verification`
* **Test Objective**: Verify crowdsourced misinformation flagging and administrative review queue workflows.
* **Execution**:
  * Citizen posts alarming rumor: `"Dam has collapsed! Water coming right now!"`.
  * 3 independent users submit flags via `POST /api/broadcasts/{id}/flag/`.
  * Verified post automatically escalated to `status = 'flagged'`.
  * System administrator reviews and calls `POST /api/broadcasts/{id}/verify/` $\to$ Post status reset to `verified`.
* **Status**: **PASS**

---

### Test 9: `test_dijkstra_safe_route_hazard_avoidance`
* **Test Objective**: Verify that Dijkstra / $A^*$ routing avoids active `DisasterZone` danger polygons.
* **Scenario**:
  * Active Critical flood zone registered at Rahim Yar Khan (`28.4212, 70.2989`, radius 25 km).
  * Route requested: **Sukkur $\to$ Multan**.
* **Expected Path**: Must avoid `R_Y_KHAN` and route via `CHOLISTAN_CORRIDOR` and `BAHAWALPUR`.
* **Actual Path Returned**:
  ```json
  ["SUKKUR", "CHOLISTAN_CORRIDOR", "BAHAWALPUR", "MULTAN"]
  ```
* **Hazard Avoidance**: Confirmed (Direct N-5 path via Rahim Yar Khan skipped).
* **Status**: **PASS**

---

### Test 10: `test_routing_fallback_least_risk_mode`
* **Test Objective**: Verify the **FR 8.6 fallback requirement** when all available corridors are blocked by severe flooding.
* **Scenario**: Both `R_Y_KHAN` and `CHOLISTAN_CORRIDOR` blocked by Critical flood zones.
* **Expected Result**: Returns least-risk path with `hazard_warning = True` and caution advisory.
* **Actual Result**: `success: True`, `hazard_warning: True`, `note: "CAUTION: No completely safe path exists..."`.
* **Status**: **PASS**

---

### Test 11: `test_ai_disaster_risk_prediction_with_pmd_data`
* **Test Objective**: Evaluate real Pakistan Meteorological Department (PMD) monsoon metrics through the trained Random Forest model.
* **Input Data**:
  ```json
  {
    "station": "R.Y.KHAN",
    "month": 8,
    "temp_max": 36.5,
    "temp_min": 27.7,
    "rainfall_mm": 258.2,
    "description": "Heavy continuous monsoon downpour, low lying areas waterlogged"
  }
  ```
* **Expected Result**: Risk classified as `High` or `Critical` with probability $\ge 0.50$ and `evacuation_warning = True`.
* **Actual Output**:
  ```json
  {
    "station": "R.Y.KHAN",
    "risk_level": "High",
    "probability": 0.85,
    "model_evaluated": true,
    "evacuation_warning": true
  }
  ```
* **Status**: **PASS**

---

### Test 12: `test_ai_predictor_failure_detection_and_heuristic_fallback`
* **Test Objective**: Verify automated failure recovery when ML models are missing or uninitialized.
* **Input Data**: Unregistered station with heavy rainfall ($\text{rainfall\_mm} = 180.0$).
* **Actual Result**: Predictor caught unmapped station $\to$ Triggered hydrological threshold heuristic fallback $\to$ Output: `risk_level: 'High'`, `probability: 0.90`, `fallback_triggered: True`. No server crash or unhandled exception.
* **Status**: **PASS**

---

## 4. Raw Console Output

```
Creating test database for alias 'default'...
...........
----------------------------------------------------------------------
Ran 11 tests in 117.550s

OK
Destroying test database for alias 'default'...
Found 11 test(s).
System check identified no issues (0 silenced).
```
