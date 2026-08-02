-- RumaLink Enterprise - Complete Database Schema
-- PostgreSQL 14+

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE plan_type AS ENUM ('hotspot', 'pppoe');
CREATE TYPE isp_status AS ENUM ('pending', 'active', 'suspended', 'cancelled');
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded', 'partial');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'expired');
CREATE TYPE session_status AS ENUM ('active', 'closed', 'expired');
CREATE TYPE voucher_status AS ENUM ('unused', 'active', 'used', 'expired');
CREATE TYPE notification_type AS ENUM ('info', 'warning', 'success', 'error');
CREATE TYPE transaction_type AS ENUM ('payment', 'refund', 'commission', 'payout', 'adjustment');

-- ============================================================
-- SUPER ADMIN / RUMALINK PLATFORM
-- ============================================================
CREATE TABLE admins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(50) DEFAULT 'superadmin',
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ISP ACCOUNTS
-- ============================================================
CREATE TABLE isps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(255) NOT NULL,
    owner_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    password_hash TEXT NOT NULL,
    plan_type plan_type NOT NULL DEFAULT 'hotspot',
    status isp_status DEFAULT 'pending',
    -- Business Details
    county VARCHAR(100),
    town VARCHAR(100),
    address TEXT,
    -- API & Integration
    api_key UUID DEFAULT uuid_generate_v4(),
    api_secret TEXT DEFAULT encode(gen_random_bytes(32), 'hex'),
    webhook_url TEXT,
    -- Billing
    wallet_balance DECIMAL(15,2) DEFAULT 0.00,
    commission_rate DECIMAL(5,4) DEFAULT 0.03, -- 3% for hotspot
    pppoe_rate_per_user DECIMAL(10,2) DEFAULT 32.25, -- $0.25 in KES approx
    total_earned DECIMAL(15,2) DEFAULT 0.00,
    total_commission_paid DECIMAL(15,2) DEFAULT 0.00,
    -- Settings
    sms_gateway VARCHAR(50),
    sms_api_key TEXT,
    sms_sender_id VARCHAR(20),
    logo_url TEXT,
    timezone VARCHAR(50) DEFAULT 'Africa/Nairobi',
    currency VARCHAR(10) DEFAULT 'KES',
    -- Verification
    email_verified BOOLEAN DEFAULT FALSE,
    email_verify_token TEXT,
    password_reset_token TEXT,
    password_reset_expires TIMESTAMPTZ,
    -- Timestamps
    trial_ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MIKROTIK / NAS DEVICES
-- ============================================================
CREATE TABLE nas_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    -- Connection Info (auto-provisioned via API)
    nas_ip VARCHAR(45),
    nas_port INTEGER DEFAULT 3799,
    secret TEXT, -- RADIUS secret
    -- Provisioning
    provision_token TEXT DEFAULT encode(gen_random_bytes(16), 'hex'),
    provision_url TEXT,
    is_provisioned BOOLEAN DEFAULT FALSE,
    provisioned_at TIMESTAMPTZ,
    -- Mikrotik specifics
    mikrotik_identity VARCHAR(255),
    mikrotik_version VARCHAR(50),
    mikrotik_board VARCHAR(100),
    mikrotik_mac VARCHAR(17),
    wan_ip VARCHAR(45),
    -- Status
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMPTZ,
    -- Service types enabled
    hotspot_enabled BOOLEAN DEFAULT FALSE,
    pppoe_enabled BOOLEAN DEFAULT FALSE,
    hotspot_profile VARCHAR(100),
    pppoe_pool VARCHAR(100),
    -- Winbox remote
    winbox_port INTEGER DEFAULT 8291,
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- HOTSPOT PACKAGES
-- ============================================================
CREATE TABLE hotspot_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id) ON DELETE CASCADE,
    nas_id UUID REFERENCES nas_devices(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    -- Limits
    price DECIMAL(10,2) NOT NULL,
    duration_hours INTEGER, -- NULL = unlimited
    bandwidth_down_mbps INTEGER, -- NULL = unlimited
    bandwidth_up_mbps INTEGER,
    data_limit_mb INTEGER, -- NULL = unlimited
    simultaneous_sessions INTEGER DEFAULT 1,
    -- MikroTik Profile
    mikrotik_profile VARCHAR(100),
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PPPOE PACKAGES / PLANS
-- ============================================================
CREATE TABLE pppoe_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    -- Billing
    price DECIMAL(10,2) NOT NULL,
    billing_cycle VARCHAR(20) DEFAULT 'monthly', -- daily, weekly, monthly
    -- Limits
    bandwidth_down_mbps INTEGER,
    bandwidth_up_mbps INTEGER,
    data_limit_gb INTEGER, -- NULL = unlimited
    burst_limit_mbps INTEGER,
    burst_threshold_mbps INTEGER,
    burst_time_seconds INTEGER,
    -- MikroTik
    mikrotik_profile VARCHAR(100),
    address_pool VARCHAR(100),
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- HOTSPOT USERS / VOUCHERS
-- ============================================================
CREATE TABLE hotspot_vouchers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id) ON DELETE CASCADE,
    package_id UUID NOT NULL REFERENCES hotspot_packages(id),
    nas_id UUID REFERENCES nas_devices(id),
    -- Voucher
    code VARCHAR(50) UNIQUE NOT NULL,
    batch_id UUID, -- group of vouchers
    status voucher_status DEFAULT 'unused',
    -- Usage
    used_by_mac VARCHAR(17),
    used_by_ip VARCHAR(45),
    used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    -- Session tracking
    bytes_downloaded BIGINT DEFAULT 0,
    bytes_uploaded BIGINT DEFAULT 0,
    time_used_seconds INTEGER DEFAULT 0,
    -- Payment
    is_paid BOOLEAN DEFAULT FALSE,
    amount_paid DECIMAL(10,2),
    payment_method VARCHAR(50),
    payment_reference TEXT,
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE voucher_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id) ON DELETE CASCADE,
    package_id UUID NOT NULL REFERENCES hotspot_packages(id),
    quantity INTEGER NOT NULL,
    prefix VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PPPOE SUBSCRIBERS
-- ============================================================
CREATE TABLE pppoe_subscribers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id) ON DELETE CASCADE,
    package_id UUID NOT NULL REFERENCES pppoe_packages(id),
    nas_id UUID REFERENCES nas_devices(id),
    -- Identity
    username VARCHAR(100) NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    id_number VARCHAR(50),
    -- Address
    county VARCHAR(100),
    town VARCHAR(100),
    area VARCHAR(100),
    physical_address TEXT,
    -- IP & Network
    static_ip VARCHAR(45), -- if static
    mac_address VARCHAR(17),
    -- Status
    status user_status DEFAULT 'active',
    -- Billing
    balance DECIMAL(10,2) DEFAULT 0.00,
    next_billing_date DATE,
    last_payment_date DATE,
    -- MikroTik
    mikrotik_profile VARCHAR(100),
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(isp_id, username)
);

-- ============================================================
-- SESSIONS
-- ============================================================
CREATE TABLE hotspot_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    voucher_id UUID REFERENCES hotspot_vouchers(id),
    nas_id UUID REFERENCES nas_devices(id),
    -- Session info (from RADIUS)
    radius_session_id VARCHAR(255),
    mac_address VARCHAR(17),
    ip_address VARCHAR(45),
    nas_ip VARCHAR(45),
    -- Usage
    bytes_downloaded BIGINT DEFAULT 0,
    bytes_uploaded BIGINT DEFAULT 0,
    session_time_seconds INTEGER DEFAULT 0,
    -- Status
    status session_status DEFAULT 'active',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    terminate_cause VARCHAR(100)
);

CREATE TABLE pppoe_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    subscriber_id UUID NOT NULL REFERENCES pppoe_subscribers(id),
    nas_id UUID REFERENCES nas_devices(id),
    -- RADIUS
    radius_session_id VARCHAR(255),
    framed_ip VARCHAR(45),
    nas_ip VARCHAR(45),
    caller_id VARCHAR(100),
    -- Usage
    bytes_downloaded BIGINT DEFAULT 0,
    bytes_uploaded BIGINT DEFAULT 0,
    session_time_seconds INTEGER DEFAULT 0,
    -- Status
    status session_status DEFAULT 'active',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    terminate_cause VARCHAR(100)
);

-- ============================================================
-- PAYMENTS & TRANSACTIONS
-- ============================================================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    -- Who paid
    subscriber_id UUID REFERENCES pppoe_subscribers(id),
    voucher_id UUID REFERENCES hotspot_vouchers(id),
    -- Amount
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'KES',
    -- Method
    payment_method VARCHAR(50) NOT NULL, -- mpesa, cash, card, bank
    payment_gateway VARCHAR(50), -- mpesa, stripe, etc
    transaction_id VARCHAR(255),
    gateway_reference TEXT,
    phone_number VARCHAR(20),
    -- Commission
    commission_amount DECIMAL(10,2) DEFAULT 0.00,
    commission_rate DECIMAL(5,4) DEFAULT 0.03,
    net_amount DECIMAL(10,2),
    -- Status
    status payment_status DEFAULT 'pending',
    failure_reason TEXT,
    -- Metadata
    description TEXT,
    metadata JSONB,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE isp_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    type transaction_type NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    balance_before DECIMAL(15,2),
    balance_after DECIMAL(15,2),
    description TEXT,
    reference_id UUID, -- payment_id or other reference
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Platform-level commission tracking
CREATE TABLE commissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    payment_id UUID NOT NULL REFERENCES payments(id),
    amount DECIMAL(10,2) NOT NULL,
    rate DECIMAL(5,4) NOT NULL,
    period_month INTEGER,
    period_year INTEGER,
    is_settled BOOLEAN DEFAULT FALSE,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Monthly PPPoE billing (per subscriber)
CREATE TABLE pppoe_invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    subscriber_id UUID NOT NULL REFERENCES pppoe_subscribers(id),
    package_id UUID NOT NULL REFERENCES pppoe_packages(id),
    -- Amounts
    amount DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL,
    -- Period
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    due_date DATE NOT NULL,
    -- Status
    status payment_status DEFAULT 'pending',
    paid_at TIMESTAMPTZ,
    payment_id UUID REFERENCES payments(id),
    -- SMS reminder sent
    reminder_sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ISP Platform billing (what ISP owes RumaLink for PPPoE)
CREATE TABLE isp_platform_invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    period_month INTEGER NOT NULL,
    period_year INTEGER NOT NULL,
    pppoe_user_count INTEGER DEFAULT 0,
    amount_per_user DECIMAL(10,2) DEFAULT 32.25,
    total_amount DECIMAL(10,2) NOT NULL,
    status payment_status DEFAULT 'pending',
    due_date DATE,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MPESA INTEGRATION
-- ============================================================
CREATE TABLE mpesa_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID UNIQUE NOT NULL REFERENCES isps(id) ON DELETE CASCADE,
    shortcode VARCHAR(20),
    consumer_key TEXT,
    consumer_secret TEXT,
    passkey TEXT,
    callback_url TEXT,
    is_sandbox BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE mpesa_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    payment_id UUID REFERENCES payments(id),
    checkout_request_id VARCHAR(255),
    merchant_request_id VARCHAR(255),
    result_code INTEGER,
    result_desc TEXT,
    amount DECIMAL(10,2),
    mpesa_receipt VARCHAR(50),
    phone VARCHAR(20),
    transaction_date TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'pending',
    raw_callback JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SMS GATEWAY
-- ============================================================
CREATE TABLE sms_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    recipient VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    gateway VARCHAR(50),
    gateway_message_id TEXT,
    status VARCHAR(50) DEFAULT 'sent',
    cost DECIMAL(10,4),
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID REFERENCES isps(id),
    admin_id UUID REFERENCES admins(id),
    type notification_type DEFAULT 'info',
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    link TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- RADIUS ACCOUNTING (from FreeRADIUS)
-- ============================================================
CREATE TABLE radacct (
    radacctid BIGSERIAL PRIMARY KEY,
    acctsessionid VARCHAR(64) NOT NULL,
    acctuniqueid VARCHAR(32) UNIQUE,
    username VARCHAR(64),
    nas_ip_address INET,
    nas_port_id VARCHAR(15),
    nas_port_type VARCHAR(32),
    acctstarttime TIMESTAMPTZ,
    acctstoptime TIMESTAMPTZ,
    acctinterval BIGINT,
    acctsessiontime BIGINT,
    acctauthentic VARCHAR(32),
    connectinfo_start TEXT,
    connectinfo_stop TEXT,
    acctinputoctets BIGINT,
    acctoutputoctets BIGINT,
    calledstationid VARCHAR(50),
    callingstationid VARCHAR(50),
    acctterminatecause VARCHAR(32),
    servicetype VARCHAR(32),
    framedprotocol VARCHAR(32),
    framedipaddress INET,
    acctstart_delay BIGINT,
    acctdelivery_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE radcheck (
    id SERIAL PRIMARY KEY,
    username VARCHAR(64) NOT NULL,
    attribute VARCHAR(64) NOT NULL,
    op CHAR(2) NOT NULL DEFAULT ':=',
    value VARCHAR(253) NOT NULL
);

CREATE TABLE radreply (
    id SERIAL PRIMARY KEY,
    username VARCHAR(64) NOT NULL,
    attribute VARCHAR(64) NOT NULL,
    op CHAR(2) NOT NULL DEFAULT '=',
    value VARCHAR(253) NOT NULL
);

CREATE TABLE radgroupcheck (
    id SERIAL PRIMARY KEY,
    groupname VARCHAR(64) NOT NULL,
    attribute VARCHAR(64) NOT NULL,
    op CHAR(2) NOT NULL DEFAULT ':=',
    value VARCHAR(253) NOT NULL
);

CREATE TABLE radgroupreply (
    id SERIAL PRIMARY KEY,
    groupname VARCHAR(64) NOT NULL,
    attribute VARCHAR(64) NOT NULL,
    op CHAR(2) NOT NULL DEFAULT '=',
    value VARCHAR(253) NOT NULL
);

CREATE TABLE radusergroup (
    username VARCHAR(64) NOT NULL,
    groupname VARCHAR(64) NOT NULL,
    priority INTEGER NOT NULL DEFAULT 1
);

-- ============================================================
-- AUDIT LOGS
-- ============================================================
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_type VARCHAR(20) NOT NULL, -- admin, isp
    actor_id UUID NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id UUID,
    changes JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SUPPORT TICKETS
-- ============================================================
CREATE TABLE support_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    isp_id UUID NOT NULL REFERENCES isps(id),
    subject VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'open',
    priority VARCHAR(20) DEFAULT 'normal',
    assigned_to UUID REFERENCES admins(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE support_replies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES support_tickets(id),
    author_type VARCHAR(20) NOT NULL,
    author_id UUID NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_isps_status ON isps(status);
CREATE INDEX idx_isps_email ON isps(email);
CREATE INDEX idx_isps_api_key ON isps(api_key);
CREATE INDEX idx_nas_isp ON nas_devices(isp_id);
CREATE INDEX idx_nas_token ON nas_devices(provision_token);
CREATE INDEX idx_vouchers_code ON hotspot_vouchers(code);
CREATE INDEX idx_vouchers_isp ON hotspot_vouchers(isp_id);
CREATE INDEX idx_vouchers_status ON hotspot_vouchers(status);
CREATE INDEX idx_pppoe_username ON pppoe_subscribers(username);
CREATE INDEX idx_pppoe_isp ON pppoe_subscribers(isp_id);
CREATE INDEX idx_payments_isp ON payments(isp_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_hotspot_sessions_status ON hotspot_sessions(status);
CREATE INDEX idx_pppoe_sessions_status ON pppoe_sessions(status);
CREATE INDEX idx_radacct_username ON radacct(username);
CREATE INDEX idx_radacct_nas ON radacct(nas_ip_address);
CREATE INDEX idx_radcheck_username ON radcheck(username);
CREATE INDEX idx_radreply_username ON radreply(username);

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO admins (name, email, password_hash, role) VALUES (
    'RumaLink Admin',
    'admin@rumalink.co.ke',
    crypt('Admin@2024!', gen_salt('bf', 12)),
    'superadmin'
);
