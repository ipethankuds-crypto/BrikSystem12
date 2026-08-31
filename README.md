# BrikSystem12 - Multi-Tenant SaaS Platform for Local Service Businesses

A production-grade, multi-tenant SaaS application designed for local service businesses (Plumbing, Electrical, HVAC, Roofing, Landscaping, Cleaning, Contractors).

Each business gets:
1. **Public-Facing Website** (`/#/site/:slug`): High-converting public landing page with services catalog, verified reviews, instant quote & booking form.
2. **Private Business Dashboard** (`/#/dashboard`): All-in-one management suite with leads pipeline, customer CRM, jobs & dispatch Kanban, appointment scheduler, automated review collection, SMS/Email automation triggers, and real-time website customizer.
3. **Strict Multi-Tenant Isolation**: Data is separated by `business_id` with PostgreSQL Row Level Security (RLS) policies.
4. **Instant Inbound Flow**: When a customer submits a quote or booking on the public website, it automatically appears in real-time in the business owner's private dashboard and triggers SMS confirmation automations.

---

## 🚀 Quick Start (Zero Setup)

You can launch and explore the platform immediately without installing any dependencies:

1. Double-click or open **[`index.html`](file:///C:/Users/losik/.gemini/antigravity/scratch/briksystem12/index.html)** in any web browser (Chrome, Edge, Firefox, Safari).
2. Use the **Tenant Switcher** in the top left to toggle between different service businesses:
   - **Apex Flow Plumbing & Heating** (`/#/site/apex-plumbing`)
   - **VoltCraft Electrical Systems** (`/#/site/voltcraft-electric`)
   - **Arctic Air Heating & Cooling** (`/#/site/arctic-air-hvac`)
   - Or click **"➕ Create New Business Tenant"** to instantly provision a new company!
3. Click **"View Public Site"** to see how the public landing page looks and submit a live quote/booking.

---

## 🗄️ Database Architecture & Schema

The platform includes a complete PostgreSQL / Supabase schema in **[`supabase_schema.sql`](file:///C:/Users/losik/.gemini/antigravity/scratch/briksystem12/supabase_schema.sql)**.

### Core Tables & Entities:
| Table | Description |
| :--- | :--- |
| `businesses` | Tenant entity storing company name, slug, trade type, phone, email, address, hours, and branding. |
| `profiles` | Multi-tenant user accounts with roles: `OWNER`, `ADMIN`, `STAFF`, `TECHNICIAN`. |
| `customers` | Client directory with contact info, addresses, notes, and past job histories. |
| `leads` | Inbound quote requests and inquiries with status pipeline (`NEW`, `CONTACTED`, `QUALIFIED`, `BOOKED`, `LOST`, `CONVERTED`). |
| `jobs` | Work orders with scheduled dates, technician dispatch, status (`SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`), and pricing. |
| `appointments` | Calendar schedule linked to customers, jobs, and service technicians. |
| `services` | Service catalog with descriptions, pricing rules, and duration estimates. |
| `reviews` | 5-star ratings, testimonials, and automated review request tracking. |
| `automation_rules` | Configurable event triggers (e.g. on `lead_created`, `job_completed`, `appointment_reminder`). |
| `messages` | Dispatched SMS and Email communication logs. |
| `website_settings` | Dynamic CMS configuration for the public website (headlines, hero images, theme colors). |

---

## 🛠️ Developer Setup (Vite + React + TypeScript)

If you have Node.js installed, you can also run the modular developer build:

```bash
# Install dependencies
npm install

# Start the local development server
npm run dev

# Build production bundle
npm run build
```

---

## 📦 Pushing to GitHub (`ipethankuds-crypto/BrikSystem12`)

To push these new files to your GitHub repository:

```bash
cd C:\Users\losik\.gemini\antigravity\scratch\briksystem12
git init
git add .
git commit -m "Initial commit: Multi-tenant SaaS platform for local service businesses"
git branch -M main
git remote add origin https://github.com/ipethankuds-crypto/BrikSystem12.git
git push -u origin main
```

---

## 🔑 Key Features Walkthrough

- **Public-to-Private Lead Ingestion**: Visitors on `/#/site/apex-plumbing` fill out the booking form; it instantly injects into `leads` and dispatches an automated SMS confirmation.
- **One-Click Lead Conversion**: Convert any incoming lead into a customer profile and schedule an on-site job with 1 click.
- **Automated Review Engine**: Changing a job status to `COMPLETED` records `completed_at` and automatically triggers an SMS to the customer requesting a 5-star review.
- **Live Website Customizer**: Edit headlines, subheadlines, story, and colors under **Website Builder** and watch changes immediately render on the public site.
- **Role-Based Access Control**: Easily switch between `OWNER`, `ADMIN`, `STAFF`, and `TECHNICIAN` to test workflow permissions.
