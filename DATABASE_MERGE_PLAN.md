# Database Merge Plan: POS + Monitor

## Overview
Merge two separate SQLite databases into a single unified database while maintaining full application functionality.

## Current State

### POS Database (`lib/back_pos/database/db_helper.dart`)
- **File pattern:** `app_db_company_{companyId}.db`
- **Version:** 12
- **Tables (8):**
  - `user` - POS users and cashiers
  - `service_point` - POS service points/terminals
  - `inventory` - Product catalog
  - `sales_transactions` - Local POS sales records
  - `cash_accounts` - Payment methods
  - `customers` - Customer data cache
  - `sync_metadata` - Sync status tracking
  - `server_sales` - Server sales cache for reconciliation

### Monitor Database (`lib/bac_monitor/lib/db/db_helper.dart`)
- **File pattern:** `app_database_{companyId}.db`
- **Version:** 7
- **Tables (4):**
  - `service_points` - Monitor service points
  - `company_details` - Company information
  - `sales` - Monitor sales data
  - `inventory` - Monitor inventory data

## Merge Strategy: Prefix Monitor Tables

### Final Unified Schema

| Table Name | Source | Purpose |
|------------|--------|---------|
| `user` | POS | POS users and cashiers |
| `service_point` | POS | POS service points |
| `inventory` | POS | POS product catalog |
| `sales_transactions` | POS | Local POS sales |
| `cash_accounts` | POS | Payment methods |
| `customers` | POS | Customer cache |
| `sync_metadata` | POS | Sync tracking |
| `server_sales` | POS | Server sales cache |
| `mon_service_points` | Monitor | Monitor service points |
| `company_details` | Monitor | Company info |
| `mon_sales` | Monitor | Monitor sales data |
| `mon_inventory` | Monitor | Monitor inventory |

**Total: 12 tables in unified database**

## Implementation Steps

### Phase 1: Create Unified Database Helper

1. Create new file: `lib/shared/database/unified_db_helper.dart`
2. Combine all table schemas
3. Set version to 1 (fresh start) or 13 (continuation)
4. Implement migration logic for existing data

### Phase 2: Update Monitor Module

Files to update:
- `lib/bac_monitor/lib/db/db_helper.dart` - Remove/deprecate
- `lib/bac_monitor/lib/services/api_services.dart` - Update table references
- `lib/bac_monitor/lib/controllers/mon_inventory_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_store_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_kpi_overview_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_salestrends_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_gross_profit_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_outstanding_payments_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_store_kpi_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_operator_controller.dart`
- `lib/bac_monitor/lib/controllers/auth_controller.dart`
- `lib/bac_monitor/lib/pages/auth/splash_page.dart`
- `lib/bac_monitor/lib/pages/nav_pages/inventory.dart`

Table name changes in Monitor code:
- `service_points` -> `mon_service_points`
- `sales` -> `mon_sales`
- `inventory` -> `mon_inventory`

### Phase 3: Update POS Module

Files to update:
- `lib/back_pos/database/db_helper.dart` - Remove/deprecate
- All controllers use unified helper

### Phase 4: Update Shared Files

- `lib/initialise/splashscreen.dart`
- `lib/back_pos/auth/login.dart`

### Phase 5: Data Migration

For existing users with data in both databases:
1. On first app launch after update
2. Detect if old databases exist
3. Copy data from old tables to new unified schema
4. Optionally delete old database files

## Backup & Rollback Plan

### Before Migration
1. Export current database files before update
2. Keep old db_helper files as backup (renamed with .bak suffix)

### Rollback Procedure
1. Restore old db_helper files
2. Restore old database files from backup
3. Rebuild app

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss during migration | Low | High | Implement data copy, not move |
| Table name reference missed | Medium | Medium | Comprehensive grep search |
| Version conflict | Low | Medium | Fresh version number |
| Performance impact | Low | Low | Indexes preserved |

## Testing Checklist

- [ ] Fresh install works (no existing data)
- [ ] POS functions work: login, sales, inventory, customers
- [ ] Monitor functions work: dashboard, reports, inventory view
- [ ] Data migration from old DBs works
- [ ] Switching between POS and Monitor views works
- [ ] Offline mode works for both modules
- [ ] Sync operations work correctly

## Estimated Changes

- **New files:** 1 (unified_db_helper.dart)
- **Modified files:** ~20-25
- **Deprecated files:** 2 (old db_helpers)
- **Table renames:** 3 (mon_service_points, mon_sales, mon_inventory)

---

## IMPLEMENTATION STATUS: COMPLETED

### Changes Made

**New File Created:**
- `lib/shared/database/unified_db_helper.dart` - Unified database helper with all 12 tables

**Files Updated (Monitor Module):**
- `lib/bac_monitor/lib/services/api_services.dart`
- `lib/bac_monitor/lib/controllers/mon_operator_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_inventory_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_store_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_kpi_overview_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_salestrends_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_gross_profit_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_outstanding_payments_controller.dart`
- `lib/bac_monitor/lib/controllers/mon_store_kpi_controller.dart`
- `lib/bac_monitor/lib/controllers/auth_controller.dart`
- `lib/bac_monitor/lib/controllers/profile_controller.dart`
- `lib/bac_monitor/lib/pages/auth/splash_page.dart`
- `lib/bac_monitor/lib/pages/nav_pages/inventory.dart`

**Files Updated (POS Module):**
- `lib/back_pos/services/api_services.dart`
- `lib/back_pos/services/sales_sync_service.dart`
- `lib/back_pos/controllers/auth_controller.dart`
- `lib/back_pos/controllers/customer_controller.dart`
- `lib/back_pos/controllers/inventory_controller.dart`
- `lib/back_pos/controllers/payment_controller.dart`
- `lib/back_pos/controllers/sales_controller.dart`
- `lib/back_pos/controllers/service_point_controller.dart`
- `lib/back_pos/controllers/settings_controller.dart`
- `lib/back_pos/controllers/user_controller.dart`
- `lib/back_pos/auth/splash_screen.dart`
- `lib/back_pos/auth/login.dart`
- `lib/back_pos/pages/pos_screen.dart`
- `lib/back_pos/pages/payment_screen.dart`

**Files Updated (Shared):**
- `lib/initialise/splashscreen.dart`

### Unified Database Schema (12 Tables)

| Table | Source | Purpose |
|-------|--------|---------|
| user | POS | POS users/cashiers |
| service_point | POS | POS service points |
| inventory | POS | POS product catalog |
| sales_transactions | POS | Local POS sales |
| cash_accounts | POS | Payment methods |
| customers | POS | Customer cache |
| sync_metadata | POS | Sync tracking |
| server_sales | POS | Server sales cache |
| mon_service_points | Monitor | Monitor service points |
| company_details | Monitor | Company info |
| mon_sales | Monitor | Monitor sales data |
| mon_inventory | Monitor | Monitor inventory |

### Database File
- **New unified database:** `unified_db_company_{companyId}.db`
- **Old POS database (deprecated):** `app_db_company_{companyId}.db`
- **Old Monitor database (deprecated):** `app_database_{companyId}.db`

### Next Steps
1. Run `flutter pub get` to ensure dependencies are resolved
2. Run `flutter analyze` to verify no compilation errors
3. Test the application to verify all functionality works
4. Consider removing the old db_helper.dart files after verification
