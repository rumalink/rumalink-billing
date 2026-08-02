--
-- PostgreSQL database dump
--

\restrict TLBcRAxtoAfpE0skrMbcnwEQajWShuf26cyAnQo35eRSVXcCrHIgQRMrNfTV0rQ

-- Dumped from database version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: isp_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.isp_status AS ENUM (
    'pending',
    'active',
    'suspended',
    'cancelled'
);


ALTER TYPE public.isp_status OWNER TO rumalink_user;

--
-- Name: notification_type; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.notification_type AS ENUM (
    'info',
    'warning',
    'success',
    'error'
);


ALTER TYPE public.notification_type OWNER TO rumalink_user;

--
-- Name: payment_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.payment_status AS ENUM (
    'pending',
    'paid',
    'failed',
    'refunded',
    'partial'
);


ALTER TYPE public.payment_status OWNER TO rumalink_user;

--
-- Name: plan_type; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.plan_type AS ENUM (
    'hotspot',
    'pppoe'
);


ALTER TYPE public.plan_type OWNER TO rumalink_user;

--
-- Name: session_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.session_status AS ENUM (
    'active',
    'closed',
    'expired'
);


ALTER TYPE public.session_status OWNER TO rumalink_user;

--
-- Name: transaction_type; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.transaction_type AS ENUM (
    'payment',
    'refund',
    'commission',
    'payout',
    'adjustment'
);


ALTER TYPE public.transaction_type OWNER TO rumalink_user;

--
-- Name: user_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.user_status AS ENUM (
    'active',
    'inactive',
    'suspended',
    'expired'
);


ALTER TYPE public.user_status OWNER TO rumalink_user;

--
-- Name: voucher_status; Type: TYPE; Schema: public; Owner: rumalink_user
--

CREATE TYPE public.voucher_status AS ENUM (
    'unused',
    'active',
    'used',
    'expired'
);


ALTER TYPE public.voucher_status OWNER TO rumalink_user;

--
-- Name: _audit_radreply_del(); Type: FUNCTION; Schema: public; Owner: rumalink_user
--

CREATE FUNCTION public._audit_radreply_del() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.username = 'benard' THEN
    INSERT INTO _radreply_audit(username, attribute, pid, query)
    VALUES (OLD.username, OLD.attribute, pg_backend_pid(), current_query());
  END IF;
  RETURN OLD;
END;
$$;


ALTER FUNCTION public._audit_radreply_del() OWNER TO rumalink_user;

--
-- Name: _rl_set(text, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._rl_set(k text, v numeric) RETURNS void
    LANGUAGE sql
    AS $$
  INSERT INTO platform_settings (key, value, updated_at) VALUES (k, v, NOW())
  ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=NOW();
$$;


ALTER FUNCTION public._rl_set(k text, v numeric) OWNER TO postgres;

--
-- Name: rl_audit_radcheck_delete(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rl_audit_radcheck_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO radcheck_delete_audit (username, app_name, client_addr, backend_pid, query_text)
  VALUES (OLD.username,
          COALESCE(current_setting('application_name', true),'?'),
          inet_client_addr(),
          pg_backend_pid(),
          (SELECT query FROM pg_stat_activity WHERE pid = pg_backend_pid()));
  RETURN OLD;
END;
$$;


ALTER FUNCTION public.rl_audit_radcheck_delete() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _mac_delete_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._mac_delete_log (
    id integer NOT NULL,
    deleted_username text,
    deleted_at timestamp with time zone DEFAULT now(),
    query text,
    app text
);


ALTER TABLE public._mac_delete_log OWNER TO postgres;

--
-- Name: _mac_delete_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public._mac_delete_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public._mac_delete_log_id_seq OWNER TO postgres;

--
-- Name: _mac_delete_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public._mac_delete_log_id_seq OWNED BY public._mac_delete_log.id;


--
-- Name: _radreply_audit; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public._radreply_audit (
    id integer NOT NULL,
    username text,
    attribute text,
    deleted_at timestamp with time zone DEFAULT now(),
    pid integer,
    query text
);


ALTER TABLE public._radreply_audit OWNER TO rumalink_user;

--
-- Name: _radreply_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public._radreply_audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public._radreply_audit_id_seq OWNER TO rumalink_user;

--
-- Name: _radreply_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public._radreply_audit_id_seq OWNED BY public._radreply_audit.id;


--
-- Name: admins; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.admins (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash text NOT NULL,
    role character varying(50) DEFAULT 'superadmin'::character varying,
    is_active boolean DEFAULT true,
    last_login timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.admins OWNER TO rumalink_user;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    actor_type character varying(20) NOT NULL,
    actor_id uuid NOT NULL,
    action character varying(100) NOT NULL,
    resource_type character varying(100),
    resource_id uuid,
    changes jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.audit_logs OWNER TO rumalink_user;

--
-- Name: commissions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.commissions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    payment_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    rate numeric(5,4) NOT NULL,
    period_month integer,
    period_year integer,
    is_settled boolean DEFAULT false,
    settled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.commissions OWNER TO rumalink_user;

--
-- Name: email_provider_config; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.email_provider_config (
    id integer NOT NULL,
    provider text DEFAULT 'resend'::text NOT NULL,
    smtp_host text,
    smtp_port integer DEFAULT 587,
    smtp_secure boolean DEFAULT false,
    smtp_user text,
    smtp_pass text,
    from_email text,
    from_name text DEFAULT 'RumaLink Enterprise'::text,
    is_active boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now(),
    logo_url text,
    logo_bg text
);


ALTER TABLE public.email_provider_config OWNER TO postgres;

--
-- Name: email_provider_config_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.email_provider_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.email_provider_config_id_seq OWNER TO postgres;

--
-- Name: email_provider_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.email_provider_config_id_seq OWNED BY public.email_provider_config.id;


--
-- Name: hotspot_bound_devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hotspot_bound_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    isp_id uuid NOT NULL,
    name text NOT NULL,
    mac_address text NOT NULL,
    buyer_phone text,
    active_voucher_id uuid,
    bound_ip text,
    package_id uuid,
    expires_at timestamp with time zone,
    is_bound boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    usage_base_in bigint DEFAULT 0,
    usage_base_out bigint DEFAULT 0,
    last_ctr_in bigint DEFAULT 0,
    last_ctr_out bigint DEFAULT 0
);


ALTER TABLE public.hotspot_bound_devices OWNER TO postgres;

--
-- Name: hotspot_packages; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.hotspot_packages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    nas_id uuid,
    name character varying(255) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    duration_hours integer,
    bandwidth_down_mbps integer,
    bandwidth_up_mbps integer,
    data_limit_mb integer,
    simultaneous_sessions integer DEFAULT 1,
    mikrotik_profile character varying(100),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.hotspot_packages OWNER TO rumalink_user;

--
-- Name: hotspot_sessions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.hotspot_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    voucher_id uuid,
    nas_id uuid,
    radius_session_id character varying(255),
    mac_address character varying(17),
    ip_address character varying(45),
    nas_ip character varying(45),
    bytes_downloaded bigint DEFAULT 0,
    bytes_uploaded bigint DEFAULT 0,
    session_time_seconds integer DEFAULT 0,
    status public.session_status DEFAULT 'active'::public.session_status,
    started_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    terminate_cause character varying(100)
);


ALTER TABLE public.hotspot_sessions OWNER TO rumalink_user;

--
-- Name: hotspot_vouchers; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.hotspot_vouchers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    package_id uuid NOT NULL,
    nas_id uuid,
    code character varying(50) NOT NULL,
    batch_id uuid,
    status public.voucher_status DEFAULT 'unused'::public.voucher_status,
    used_by_mac character varying(17),
    used_by_ip character varying(45),
    used_at timestamp with time zone,
    expires_at timestamp with time zone,
    bytes_downloaded bigint DEFAULT 0,
    bytes_uploaded bigint DEFAULT 0,
    time_used_seconds integer DEFAULT 0,
    is_paid boolean DEFAULT false,
    amount_paid numeric(10,2),
    payment_method character varying(50),
    payment_reference text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    buyer_phone character varying(20),
    sms_sent boolean DEFAULT false,
    expiry_sms_sent boolean DEFAULT false,
    payment_id uuid,
    is_test boolean DEFAULT false,
    password text DEFAULT substr(translate(lower(encode(public.gen_random_bytes(8), 'hex'::text)), '01'::text, 'xy'::text), 1, 6),
    is_tv boolean DEFAULT false,
    tv_mac text,
    created_by_isp boolean DEFAULT false,
    import_batch text,
    purchased_by_mac character varying
);


ALTER TABLE public.hotspot_vouchers OWNER TO rumalink_user;

--
-- Name: intasend_withdrawals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.intasend_withdrawals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    isp_id uuid NOT NULL,
    method character varying(20) NOT NULL,
    destination jsonb NOT NULL,
    gross_amount numeric(12,2) NOT NULL,
    fee_amount numeric(12,2) NOT NULL,
    net_amount numeric(12,2) NOT NULL,
    below_threshold boolean DEFAULT false,
    status character varying(20) DEFAULT 'pending'::character varying,
    intasend_ref character varying(128),
    intasend_state character varying(40),
    failure_reason text,
    balance_before numeric(12,2),
    balance_after numeric(12,2),
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.intasend_withdrawals OWNER TO postgres;

--
-- Name: isp_captive_portal; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isp_captive_portal (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    template character varying(50) DEFAULT 'classic'::character varying,
    primary_color character varying(20) DEFAULT '#00d4aa'::character varying,
    secondary_color character varying(20) DEFAULT '#0d1530'::character varying,
    logo_url text,
    welcome_title character varying(255) DEFAULT 'Welcome! Connect to WiFi'::character varying,
    welcome_subtitle text DEFAULT 'Select a package below to get started'::text,
    bg_image_url text,
    show_logo boolean DEFAULT true,
    show_powered_by boolean DEFAULT true,
    custom_css text,
    updated_at timestamp with time zone DEFAULT now(),
    support_number character varying(255),
    support_label character varying(255),
    enable_tv_mode boolean DEFAULT false,
    notif_enabled boolean DEFAULT false,
    notif_title character varying(255),
    notif_message text,
    notif_severity character varying(20) DEFAULT 'info'::character varying,
    notif_start timestamp with time zone,
    notif_end timestamp with time zone,
    media_enabled boolean DEFAULT false,
    media_type character varying(20) DEFAULT 'carousel'::character varying,
    media_video_url text,
    media_images jsonb DEFAULT '[]'::jsonb,
    media_interval integer DEFAULT 4,
    media_fit character varying(10) DEFAULT 'contain'::character varying
);


ALTER TABLE public.isp_captive_portal OWNER TO rumalink_user;

--
-- Name: isp_payment_methods; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isp_payment_methods (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    method_type character varying(30) NOT NULL,
    label character varying(100),
    shortcode character varying(20),
    consumer_key text,
    consumer_secret text,
    passkey text,
    is_sandbox boolean DEFAULT false,
    use_admin_credentials boolean DEFAULT false,
    till_number character varying(20),
    paybill_number character varying(20),
    account_reference character varying(100),
    bank_name character varying(100),
    account_name character varying(100),
    account_number character varying(50),
    branch character varying(100),
    forward_to_type character varying(30),
    forward_to_number character varying(50),
    forward_to_name character varying(100),
    is_active boolean DEFAULT true,
    is_verified boolean DEFAULT false,
    is_default boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    provider character varying(32),
    environment character varying(50) DEFAULT 'production'::character varying
);


ALTER TABLE public.isp_payment_methods OWNER TO rumalink_user;

--
-- Name: isp_platform_invoices; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isp_platform_invoices (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    period_month integer NOT NULL,
    period_year integer NOT NULL,
    pppoe_user_count integer DEFAULT 0,
    amount_per_user numeric(10,2) DEFAULT 32.00,
    total_amount numeric(10,2) NOT NULL,
    status public.payment_status DEFAULT 'pending'::public.payment_status,
    due_date date,
    paid_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    invoice_number character varying(30),
    invoice_type character varying(30) DEFAULT 'pppoe_monthly'::character varying,
    payment_id uuid,
    hotspot_revenue numeric(12,2) DEFAULT 0,
    hotspot_fee numeric(12,2) DEFAULT 0,
    hotspot_rate numeric(6,4) DEFAULT 0.03,
    pppoe_fee numeric(12,2) DEFAULT 0,
    window_start timestamp with time zone,
    window_end timestamp with time zone,
    period_expires_at timestamp with time zone
);


ALTER TABLE public.isp_platform_invoices OWNER TO rumalink_user;

--
-- Name: isp_transactions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isp_transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    type public.transaction_type NOT NULL,
    amount numeric(15,2) NOT NULL,
    balance_before numeric(15,2),
    balance_after numeric(15,2),
    description text,
    reference_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.isp_transactions OWNER TO rumalink_user;

--
-- Name: isps; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.isps (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    company_name character varying(255) NOT NULL,
    owner_name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    phone character varying(20) NOT NULL,
    password_hash text NOT NULL,
    plan_type character varying(20) DEFAULT 'hotspot'::public.plan_type NOT NULL,
    status public.isp_status DEFAULT 'pending'::public.isp_status,
    county character varying(100),
    town character varying(100),
    address text,
    api_key uuid DEFAULT public.uuid_generate_v4(),
    api_secret text DEFAULT encode(public.gen_random_bytes(32), 'hex'::text),
    webhook_url text,
    wallet_balance numeric(15,2) DEFAULT 0.00,
    commission_rate numeric(5,4) DEFAULT 0.03,
    pppoe_rate_per_user numeric(10,2) DEFAULT 32.25,
    total_earned numeric(15,2) DEFAULT 0.00,
    total_commission_paid numeric(15,2) DEFAULT 0.00,
    sms_gateway character varying(50),
    sms_api_key text,
    sms_sender_id character varying(20),
    logo_url text,
    timezone character varying(50) DEFAULT 'Africa/Nairobi'::character varying,
    currency character varying(10) DEFAULT 'KES'::character varying,
    email_verified boolean DEFAULT false,
    email_verify_token text,
    password_reset_token text,
    password_reset_expires timestamp with time zone,
    trial_ends_at timestamp with time zone DEFAULT (now() + '30 days'::interval),
    last_login timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    sms_username character varying(100),
    sms_partner_id character varying(100),
    sms_api_secret text,
    support_number character varying(30),
    hotspot_counter integer DEFAULT 0,
    subscription_started_at timestamp with time zone,
    license_expires_at timestamp with time zone,
    billing_window_start timestamp with time zone,
    license_status character varying(20) DEFAULT 'trial'::character varying,
    billing_exempt boolean DEFAULT false,
    sms_balance numeric(12,4) DEFAULT 0 NOT NULL,
    phone_verified boolean DEFAULT false,
    phone_verified_at timestamp with time zone,
    email_verified_at timestamp with time zone
);


ALTER TABLE public.isps OWNER TO rumalink_user;

--
-- Name: mac_auth_cache; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.mac_auth_cache (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    mac_address character varying(17) NOT NULL,
    isp_id uuid,
    package_id uuid,
    authorized_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.mac_auth_cache OWNER TO rumalink_user;

--
-- Name: mpesa_configs; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.mpesa_configs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid,
    shortcode character varying(20),
    consumer_key text,
    consumer_secret text,
    passkey text,
    callback_url text,
    is_sandbox boolean DEFAULT false,
    is_active boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_admin_config boolean DEFAULT false
);


ALTER TABLE public.mpesa_configs OWNER TO rumalink_user;

--
-- Name: mpesa_transactions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.mpesa_transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    payment_id uuid,
    checkout_request_id character varying(255),
    merchant_request_id character varying(255),
    result_code integer,
    result_desc text,
    amount numeric(10,2),
    mpesa_receipt character varying(50),
    phone character varying(20),
    transaction_date timestamp with time zone,
    status character varying(50) DEFAULT 'pending'::character varying,
    raw_callback jsonb,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.mpesa_transactions OWNER TO rumalink_user;

--
-- Name: nas; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas (
    id integer NOT NULL,
    nasname text NOT NULL,
    shortname text NOT NULL,
    type text DEFAULT 'other'::text NOT NULL,
    ports integer,
    secret text NOT NULL,
    server text,
    community text,
    description text
);


ALTER TABLE public.nas OWNER TO rumalink_user;

--
-- Name: nas_devices; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas_devices (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    nas_ip character varying(45),
    nas_port integer DEFAULT 3799,
    secret text,
    provision_token text DEFAULT encode(public.gen_random_bytes(16), 'hex'::text),
    provision_url text,
    is_provisioned boolean DEFAULT false,
    provisioned_at timestamp with time zone,
    mikrotik_identity character varying(255),
    mikrotik_version character varying(50),
    mikrotik_board character varying(100),
    mikrotik_mac character varying(17),
    wan_ip character varying(45),
    is_online boolean DEFAULT false,
    last_seen timestamp with time zone,
    hotspot_enabled boolean DEFAULT false,
    pppoe_enabled boolean DEFAULT false,
    hotspot_profile character varying(100),
    pppoe_pool character varying(100),
    winbox_port integer DEFAULT 8291,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    antishare_enabled boolean DEFAULT false,
    antishare_max_devices integer DEFAULT 1,
    bridged_ports jsonb DEFAULT '[]'::jsonb,
    bridge_ports text DEFAULT 'ether2,ether3,ether4'::text,
    hotspot_interface text DEFAULT 'bridge1'::text,
    pppoe_interface text DEFAULT 'ether1'::text,
    gateway_ip text DEFAULT '192.168.88.1'::text,
    ip_pool_start text DEFAULT '192.168.88.10'::text,
    ip_pool_end text DEFAULT '192.168.88.254'::text,
    dns_primary text DEFAULT '8.8.8.8'::text,
    dns_secondary text DEFAULT '8.8.4.4'::text,
    hotspot_network character varying(20),
    hotspot_gateway character varying(45),
    hotspot_pool_start character varying(45),
    hotspot_pool_end character varying(45),
    mikrotik_api_user character varying(100),
    mikrotik_api_password text,
    remote_winbox_url text,
    provision_step character varying(30) DEFAULT 'pending'::character varying,
    cpu_load integer DEFAULT 0,
    memory_used_mb integer DEFAULT 0,
    memory_total_mb integer DEFAULT 0,
    disk_used_mb integer DEFAULT 0,
    disk_total_mb integer DEFAULT 0,
    uptime_seconds bigint DEFAULT 0,
    wan_interface character varying(50),
    available_interfaces character varying(255),
    wireguard_private_key text,
    wireguard_public_key text,
    wireguard_ip character varying(20),
    radius_secret character varying(64),
    winbox_proxy_port integer,
    isp_link_status character varying(10) DEFAULT 'unknown'::character varying,
    isp_link_changed_at timestamp with time zone,
    isp_link_last_checked timestamp with time zone,
    isp_link_consecutive_failures integer DEFAULT 0,
    isp_link_notifications_enabled boolean DEFAULT true,
    multi_wan_mode character varying(20) DEFAULT 'none'::character varying,
    wan1_interface character varying(20),
    wan1_gateway character varying(50),
    wan1_ping_target character varying(50) DEFAULT '8.8.8.8'::character varying,
    wan2_interface character varying(20),
    wan2_gateway character varying(50),
    wan2_ping_target character varying(50) DEFAULT '1.1.1.1'::character varying,
    multi_wan_check_interval integer DEFAULT 10,
    multi_wan_fail_threshold integer DEFAULT 3,
    lb_weight_wan1 integer DEFAULT 50,
    pcc_mode character varying(40) DEFAULT 'both-addresses'::character varying,
    multi_wan_applied_at timestamp with time zone,
    wan_quality_enabled boolean DEFAULT true,
    wan_quality_latency_ms integer DEFAULT 100,
    wan_quality_jitter_ms integer DEFAULT 30,
    wan_quality_loss_pct integer DEFAULT 2,
    wan_quality_trip_count integer DEFAULT 3,
    wan_quality_recover_count integer DEFAULT 20,
    wan_type character varying(10) DEFAULT 'dhcp'::character varying,
    wan_pppoe_user character varying(128),
    wan_pppoe_pass character varying(128),
    wan_static_ip character varying(32),
    wan_static_gw character varying(32),
    wan_selected boolean DEFAULT false,
    wan_quality_min_mbps numeric DEFAULT 3
);


ALTER TABLE public.nas_devices OWNER TO rumalink_user;

--
-- Name: nas_events; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas_events (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nas_id uuid NOT NULL,
    isp_id uuid NOT NULL,
    event_type character varying(50) NOT NULL,
    message text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.nas_events OWNER TO rumalink_user;

--
-- Name: nas_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.nas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.nas_id_seq OWNER TO rumalink_user;

--
-- Name: nas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.nas_id_seq OWNED BY public.nas.id;


--
-- Name: nas_wan_links; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas_wan_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nas_id uuid NOT NULL,
    "position" integer NOT NULL,
    name character varying(120),
    interface character varying(40) NOT NULL,
    gateway character varying(80),
    ping_target character varying(80) DEFAULT '8.8.8.8'::character varying,
    role character varying(30) DEFAULT 'dedicated'::character varying NOT NULL,
    lb_weight integer DEFAULT 50,
    enabled boolean DEFAULT true,
    current_status character varying(20) DEFAULT 'unknown'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    resolved_ip character varying(40),
    resolved_gateway character varying(40),
    last_checked_at timestamp with time zone,
    last_rtt character varying(30),
    is_active boolean DEFAULT false,
    internet_ok boolean DEFAULT false,
    in_load_balance boolean DEFAULT false NOT NULL,
    is_failover boolean DEFAULT false NOT NULL,
    failover_priority integer,
    last_latency_ms numeric,
    last_jitter_ms numeric,
    last_loss_pct numeric,
    quality_state character varying(12) DEFAULT 'good'::character varying,
    consec_degraded integer DEFAULT 0,
    consec_good integer DEFAULT 0,
    quality_parked boolean DEFAULT false,
    probe_verdict character varying(24),
    probe_stage character varying(24),
    dns_ms integer,
    connect_ms integer,
    fetch_ms integer,
    throughput_kbps integer,
    last_fetch_at timestamp with time zone,
    consec_fetch_fail integer DEFAULT 0,
    sample_history text DEFAULT ''::text,
    consec_slow integer DEFAULT 0,
    bytes_carried bigint DEFAULT 0,
    bytes_since timestamp with time zone DEFAULT now(),
    last_tx_bytes bigint,
    last_rx_bytes bigint,
    bytes_month_start date,
    in_pool boolean DEFAULT true,
    last_mbps numeric,
    tp_checked_at timestamp with time zone
);


ALTER TABLE public.nas_wan_links OWNER TO rumalink_user;

--
-- Name: nas_wan_policies; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nas_wan_policies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nas_id uuid NOT NULL,
    priority integer NOT NULL,
    name character varying(200),
    match_type character varying(40) NOT NULL,
    match_value text,
    action_type character varying(30) DEFAULT 'use_link'::character varying NOT NULL,
    target_link_id uuid,
    target_link_ids uuid[] DEFAULT ARRAY[]::uuid[],
    enabled boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.nas_wan_policies OWNER TO rumalink_user;

--
-- Name: nasreload; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.nasreload (
    nasipaddress inet NOT NULL,
    reloadtime timestamp with time zone NOT NULL
);


ALTER TABLE public.nasreload OWNER TO rumalink_user;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid,
    admin_id uuid,
    type public.notification_type DEFAULT 'info'::public.notification_type,
    title character varying(255) NOT NULL,
    message text NOT NULL,
    is_read boolean DEFAULT false,
    link text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.notifications OWNER TO rumalink_user;

--
-- Name: payment_provider_configs; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.payment_provider_configs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider character varying(32) NOT NULL,
    label character varying(120),
    merchant_code character varying(120),
    consumer_key text,
    consumer_secret text,
    api_key text,
    private_key text,
    public_key text,
    base_url text,
    is_sandbox boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.payment_provider_configs OWNER TO rumalink_user;

--
-- Name: payments; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    subscriber_id uuid,
    voucher_id uuid,
    amount numeric(10,2) NOT NULL,
    currency character varying(10) DEFAULT 'KES'::character varying,
    payment_method character varying(50) NOT NULL,
    payment_gateway character varying(50),
    transaction_id character varying(255),
    gateway_reference text,
    phone_number character varying(20),
    commission_amount numeric(10,2) DEFAULT 0.00,
    commission_rate numeric(5,4) DEFAULT 0.03,
    net_amount numeric(10,2),
    status public.payment_status DEFAULT 'pending'::public.payment_status,
    failure_reason text,
    description text,
    metadata jsonb,
    paid_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    used_admin_credentials boolean DEFAULT false,
    forwarded_to character varying(100),
    forwarded_at timestamp with time zone,
    forward_status character varying(30),
    mpesa_phone character varying(20),
    mpesa_amount numeric(12,2),
    mpesa_name character varying(150),
    clearing_status character varying(24),
    cleared_at timestamp with time zone,
    intasend_invoice character varying(64),
    mpesa_receipt character varying(64),
    voucher_activated_at timestamp with time zone
);


ALTER TABLE public.payments OWNER TO rumalink_user;

--
-- Name: platform_secrets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.platform_secrets (
    key text NOT NULL,
    value text NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.platform_secrets OWNER TO postgres;

--
-- Name: platform_settings; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.platform_settings (
    key text NOT NULL,
    value numeric(12,4),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.platform_settings OWNER TO rumalink_user;

--
-- Name: pppoe_invoices; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.pppoe_invoices (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    subscriber_id uuid NOT NULL,
    package_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    tax_amount numeric(10,2) DEFAULT 0.00,
    total_amount numeric(10,2) NOT NULL,
    billing_period_start date NOT NULL,
    billing_period_end date NOT NULL,
    due_date date NOT NULL,
    status public.payment_status DEFAULT 'pending'::public.payment_status,
    paid_at timestamp with time zone,
    payment_id uuid,
    reminder_sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.pppoe_invoices OWNER TO rumalink_user;

--
-- Name: pppoe_packages; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.pppoe_packages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    billing_cycle character varying(20) DEFAULT 'monthly'::character varying,
    bandwidth_down_mbps integer,
    bandwidth_up_mbps integer,
    data_limit_gb integer,
    burst_limit_mbps integer,
    burst_threshold_mbps integer,
    burst_time_seconds integer,
    mikrotik_profile character varying(100),
    address_pool character varying(100),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.pppoe_packages OWNER TO rumalink_user;

--
-- Name: pppoe_sessions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.pppoe_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    subscriber_id uuid NOT NULL,
    nas_id uuid,
    radius_session_id character varying(255),
    framed_ip character varying(45),
    nas_ip character varying(45),
    caller_id character varying(100),
    bytes_downloaded bigint DEFAULT 0,
    bytes_uploaded bigint DEFAULT 0,
    session_time_seconds integer DEFAULT 0,
    status public.session_status DEFAULT 'active'::public.session_status,
    started_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    terminate_cause character varying(100)
);


ALTER TABLE public.pppoe_sessions OWNER TO rumalink_user;

--
-- Name: pppoe_subscribers; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.pppoe_subscribers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    package_id uuid NOT NULL,
    nas_id uuid,
    username character varying(100) NOT NULL,
    password_hash text NOT NULL,
    full_name character varying(255) NOT NULL,
    phone character varying(20),
    email character varying(255),
    id_number character varying(50),
    county character varying(100),
    town character varying(100),
    area character varying(100),
    physical_address text,
    static_ip character varying(45),
    mac_address character varying(17),
    status public.user_status DEFAULT 'active'::public.user_status,
    balance numeric(10,2) DEFAULT 0.00,
    next_billing_date timestamp with time zone,
    last_payment_date date,
    mikrotik_profile character varying(100),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    payment_sms_sent_at timestamp with time zone,
    expiry_reminder_sent boolean DEFAULT false,
    is_test boolean DEFAULT false,
    import_batch text
);


ALTER TABLE public.pppoe_subscribers OWNER TO rumalink_user;

--
-- Name: radacct; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radacct (
    radacctid bigint NOT NULL,
    acctsessionid character varying(64) NOT NULL,
    acctuniqueid character varying(32),
    username character varying(64),
    nasipaddress inet,
    nasportid character varying(15),
    nasporttype character varying(32),
    acctstarttime timestamp with time zone,
    acctstoptime timestamp with time zone,
    acctinterval bigint,
    acctsessiontime bigint,
    acctauthentic character varying(32),
    connectinfo_start text,
    connectinfo_stop text,
    acctinputoctets bigint,
    acctoutputoctets bigint,
    calledstationid character varying(50),
    callingstationid character varying(50),
    acctterminatecause character varying(32),
    servicetype character varying(32),
    framedprotocol character varying(32),
    framedipaddress inet,
    acctstart_delay bigint,
    acctdelivery_date timestamp with time zone DEFAULT now(),
    realm text,
    acctupdatetime timestamp with time zone,
    framedipv6address inet,
    framedipv6prefix text,
    framedinterfaceid text,
    delegatedipv6prefix inet
);


ALTER TABLE public.radacct OWNER TO rumalink_user;

--
-- Name: radacct_radacctid_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radacct_radacctid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radacct_radacctid_seq OWNER TO rumalink_user;

--
-- Name: radacct_radacctid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radacct_radacctid_seq OWNED BY public.radacct.radacctid;


--
-- Name: radcheck; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radcheck (
    id integer NOT NULL,
    username character varying(64) NOT NULL,
    attribute character varying(64) NOT NULL,
    op character(2) DEFAULT ':='::bpchar NOT NULL,
    value character varying(253) NOT NULL
);


ALTER TABLE public.radcheck OWNER TO rumalink_user;

--
-- Name: radcheck_delete_audit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.radcheck_delete_audit (
    id integer NOT NULL,
    deleted_at timestamp with time zone DEFAULT now(),
    username text,
    app_name text,
    client_addr inet,
    backend_pid integer,
    query_text text
);


ALTER TABLE public.radcheck_delete_audit OWNER TO postgres;

--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.radcheck_delete_audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radcheck_delete_audit_id_seq OWNER TO postgres;

--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.radcheck_delete_audit_id_seq OWNED BY public.radcheck_delete_audit.id;


--
-- Name: radcheck_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radcheck_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radcheck_id_seq OWNER TO rumalink_user;

--
-- Name: radcheck_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radcheck_id_seq OWNED BY public.radcheck.id;


--
-- Name: radgroupcheck; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radgroupcheck (
    id integer NOT NULL,
    groupname character varying(64) NOT NULL,
    attribute character varying(64) NOT NULL,
    op character(2) DEFAULT ':='::bpchar NOT NULL,
    value character varying(253) NOT NULL
);


ALTER TABLE public.radgroupcheck OWNER TO rumalink_user;

--
-- Name: radgroupcheck_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radgroupcheck_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radgroupcheck_id_seq OWNER TO rumalink_user;

--
-- Name: radgroupcheck_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radgroupcheck_id_seq OWNED BY public.radgroupcheck.id;


--
-- Name: radgroupreply; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radgroupreply (
    id integer NOT NULL,
    groupname character varying(64) NOT NULL,
    attribute character varying(64) NOT NULL,
    op character(2) DEFAULT '='::bpchar NOT NULL,
    value character varying(253) NOT NULL
);


ALTER TABLE public.radgroupreply OWNER TO rumalink_user;

--
-- Name: radgroupreply_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radgroupreply_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radgroupreply_id_seq OWNER TO rumalink_user;

--
-- Name: radgroupreply_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radgroupreply_id_seq OWNED BY public.radgroupreply.id;


--
-- Name: radius_nas_clients; Type: VIEW; Schema: public; Owner: rumalink_user
--

CREATE VIEW public.radius_nas_clients AS
 SELECT nd.id,
    nd.name AS shortname,
    nd.wireguard_ip AS nasname,
    nd.radius_secret AS secret,
    i.company_name AS description,
    nd.isp_id,
    'mikrotik'::text AS type,
    NULL::text AS server
   FROM (public.nas_devices nd
     LEFT JOIN public.isps i ON ((i.id = nd.isp_id)))
  WHERE ((nd.wireguard_ip IS NOT NULL) AND (nd.radius_secret IS NOT NULL));


ALTER VIEW public.radius_nas_clients OWNER TO rumalink_user;

--
-- Name: radpostauth; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radpostauth (
    id bigint NOT NULL,
    username character varying(64) NOT NULL,
    pass character varying(64),
    reply character varying(32),
    authdate timestamp with time zone DEFAULT now(),
    class character varying(64)
);


ALTER TABLE public.radpostauth OWNER TO rumalink_user;

--
-- Name: radpostauth_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radpostauth_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radpostauth_id_seq OWNER TO rumalink_user;

--
-- Name: radpostauth_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radpostauth_id_seq OWNED BY public.radpostauth.id;


--
-- Name: radreply; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radreply (
    id integer NOT NULL,
    username character varying(64) NOT NULL,
    attribute character varying(64) NOT NULL,
    op character(2) DEFAULT '='::bpchar NOT NULL,
    value character varying(253) NOT NULL
);


ALTER TABLE public.radreply OWNER TO rumalink_user;

--
-- Name: radreply_id_seq; Type: SEQUENCE; Schema: public; Owner: rumalink_user
--

CREATE SEQUENCE public.radreply_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.radreply_id_seq OWNER TO rumalink_user;

--
-- Name: radreply_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rumalink_user
--

ALTER SEQUENCE public.radreply_id_seq OWNED BY public.radreply.id;


--
-- Name: radusergroup; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.radusergroup (
    username character varying(64) NOT NULL,
    groupname character varying(64) NOT NULL,
    priority integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.radusergroup OWNER TO rumalink_user;

--
-- Name: shop_categories; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(100) NOT NULL,
    slug character varying(120),
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.shop_categories OWNER TO rumalink_user;

--
-- Name: shop_order_items; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_order_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid,
    product_name character varying(200) NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    line_total numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    product_image text
);


ALTER TABLE public.shop_order_items OWNER TO rumalink_user;

--
-- Name: shop_orders; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_orders (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_number character varying(20) NOT NULL,
    customer_name character varying(150) NOT NULL,
    customer_phone character varying(20) NOT NULL,
    customer_email character varying(150),
    delivery_address text NOT NULL,
    delivery_notes text,
    subtotal numeric(10,2) DEFAULT 0 NOT NULL,
    delivery_fee numeric(10,2) DEFAULT 0 NOT NULL,
    total numeric(10,2) DEFAULT 0 NOT NULL,
    status character varying(30) DEFAULT 'pending_payment'::character varying NOT NULL,
    payment_status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    mpesa_checkout_id character varying(120),
    mpesa_receipt character varying(60),
    paid_at timestamp with time zone,
    notified_admin boolean DEFAULT false,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    delivery_type character varying(20) DEFAULT 'none'::character varying,
    delivery_location text,
    map_location text,
    admin_seen boolean DEFAULT false
);


ALTER TABLE public.shop_orders OWNER TO rumalink_user;

--
-- Name: shop_payments; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    phone_number character varying(20),
    mpesa_checkout_id character varying(120),
    mpesa_receipt character varying(60),
    status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    raw_callback jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.shop_payments OWNER TO rumalink_user;

--
-- Name: shop_products; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_products (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    category_id uuid,
    name character varying(200) NOT NULL,
    slug character varying(220),
    description text,
    price numeric(10,2) DEFAULT 0 NOT NULL,
    compare_price numeric(10,2),
    sku character varying(80),
    stock_qty integer DEFAULT 0,
    track_stock boolean DEFAULT true,
    image_url text,
    images jsonb DEFAULT '[]'::jsonb,
    is_active boolean DEFAULT true,
    is_featured boolean DEFAULT false,
    weight_kg numeric(8,2),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    supplier_name text,
    supplier_phone character varying(30),
    supplier_price numeric(10,2)
);


ALTER TABLE public.shop_products OWNER TO rumalink_user;

--
-- Name: shop_settings; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.shop_settings (
    id integer DEFAULT 1 NOT NULL,
    default_delivery_fee numeric(10,2) DEFAULT 0,
    free_delivery_over numeric(10,2),
    currency character varying(10) DEFAULT 'KES'::character varying,
    shop_enabled boolean DEFAULT true,
    whatsapp_enabled boolean DEFAULT false,
    whatsapp_phone_id text,
    whatsapp_token text,
    whatsapp_admin_numbers text,
    order_prefix character varying(10) DEFAULT 'RL'::character varying,
    updated_at timestamp with time zone DEFAULT now(),
    free_delivery_locations text DEFAULT ''::text,
    CONSTRAINT single_row CHECK ((id = 1))
);


ALTER TABLE public.shop_settings OWNER TO rumalink_user;

--
-- Name: sms_credit_transactions; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.sms_credit_transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid,
    txn_type text NOT NULL,
    sms_count numeric(12,4) NOT NULL,
    unit_price numeric(10,4),
    unit_cost numeric(10,4),
    amount_paid numeric(12,2),
    profit numeric(12,4),
    isp_balance_after numeric(12,4),
    payment_id uuid,
    status text DEFAULT 'completed'::text,
    note text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.sms_credit_transactions OWNER TO rumalink_user;

--
-- Name: sms_logs; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.sms_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    recipient character varying(20) NOT NULL,
    message text NOT NULL,
    gateway character varying(50),
    gateway_message_id text,
    status character varying(50) DEFAULT 'sent'::character varying,
    cost numeric(10,4),
    sent_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.sms_logs OWNER TO rumalink_user;

--
-- Name: sms_provider_config; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.sms_provider_config (
    id integer DEFAULT 1 NOT NULL,
    provider text DEFAULT 'talksasa'::text,
    api_key text,
    sender_id text,
    base_url text DEFAULT 'https://bulksms.talksasa.com/api/v3'::text,
    is_active boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT single_row CHECK ((id = 1))
);


ALTER TABLE public.sms_provider_config OWNER TO rumalink_user;

--
-- Name: support_replies; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.support_replies (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    ticket_id uuid NOT NULL,
    author_type character varying(20) NOT NULL,
    author_id uuid NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.support_replies OWNER TO rumalink_user;

--
-- Name: support_tickets; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.support_tickets (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    subject character varying(255) NOT NULL,
    message text NOT NULL,
    status character varying(50) DEFAULT 'open'::character varying,
    priority character varying(20) DEFAULT 'normal'::character varying,
    assigned_to uuid,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.support_tickets OWNER TO rumalink_user;

--
-- Name: system_health; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_health (
    id bigint NOT NULL,
    sampled_at timestamp with time zone DEFAULT now() NOT NULL,
    load1 numeric,
    cpu_steal numeric,
    mem_total_mb integer,
    mem_avail_mb integer,
    swap_used_mb integer,
    disk_pct integer,
    freeradius_mb integer,
    node_mb integer,
    pg_conns integer,
    routers_total integer,
    routers_down integer,
    status text
);


ALTER TABLE public.system_health OWNER TO postgres;

--
-- Name: system_health_alerts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_health_alerts (
    id bigint NOT NULL,
    metric text NOT NULL,
    severity text NOT NULL,
    value numeric,
    threshold numeric,
    message text,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone
);


ALTER TABLE public.system_health_alerts OWNER TO postgres;

--
-- Name: system_health_alerts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.system_health_alerts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_health_alerts_id_seq OWNER TO postgres;

--
-- Name: system_health_alerts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.system_health_alerts_id_seq OWNED BY public.system_health_alerts.id;


--
-- Name: system_health_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.system_health_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_health_id_seq OWNER TO postgres;

--
-- Name: system_health_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.system_health_id_seq OWNED BY public.system_health.id;


--
-- Name: usage_daily; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_daily (
    isp_id uuid NOT NULL,
    device_id uuid NOT NULL,
    username text NOT NULL,
    usage_day date NOT NULL,
    bytes_in bigint DEFAULT 0 NOT NULL,
    bytes_out bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.usage_daily OWNER TO postgres;

--
-- Name: usage_daily_pre_fix; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_daily_pre_fix (
    isp_id uuid,
    device_id uuid,
    username text,
    usage_day date,
    bytes_in bigint,
    bytes_out bigint,
    updated_at timestamp with time zone
);


ALTER TABLE public.usage_daily_pre_fix OWNER TO postgres;

--
-- Name: usage_session_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_session_state (
    acctsessionid text NOT NULL,
    acctuniqueid text,
    username text,
    isp_id uuid,
    device_id uuid,
    last_in bigint DEFAULT 0 NOT NULL,
    last_out bigint DEFAULT 0 NOT NULL,
    last_seen timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.usage_session_state OWNER TO postgres;

--
-- Name: usage_session_state_v2; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_session_state_v2 (
    acctuniqueid text NOT NULL,
    acctsessionid text,
    username text,
    isp_id uuid,
    device_id uuid,
    last_in bigint DEFAULT 0 NOT NULL,
    last_out bigint DEFAULT 0 NOT NULL,
    last_seen timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.usage_session_state_v2 OWNER TO postgres;

--
-- Name: verification_codes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.verification_codes (
    id bigint NOT NULL,
    isp_id uuid,
    channel text NOT NULL,
    target text NOT NULL,
    code_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    consumed_at timestamp with time zone,
    ip text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    selector text,
    CONSTRAINT verification_codes_channel_check CHECK ((channel = ANY (ARRAY['phone'::text, 'email'::text])))
);


ALTER TABLE public.verification_codes OWNER TO postgres;

--
-- Name: verification_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.verification_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.verification_codes_id_seq OWNER TO postgres;

--
-- Name: verification_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.verification_codes_id_seq OWNED BY public.verification_codes.id;


--
-- Name: voucher_batches; Type: TABLE; Schema: public; Owner: rumalink_user
--

CREATE TABLE public.voucher_batches (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    isp_id uuid NOT NULL,
    package_id uuid NOT NULL,
    quantity integer NOT NULL,
    prefix character varying(20),
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.voucher_batches OWNER TO rumalink_user;

--
-- Name: wan_usage_monthly; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wan_usage_monthly (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    link_id uuid NOT NULL,
    nas_id uuid,
    isp_id uuid,
    "position" integer,
    interface character varying(32),
    usage_month date NOT NULL,
    bytes_carried bigint DEFAULT 0 NOT NULL,
    archived_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.wan_usage_monthly OWNER TO postgres;

--
-- Name: _mac_delete_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._mac_delete_log ALTER COLUMN id SET DEFAULT nextval('public._mac_delete_log_id_seq'::regclass);


--
-- Name: _radreply_audit id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public._radreply_audit ALTER COLUMN id SET DEFAULT nextval('public._radreply_audit_id_seq'::regclass);


--
-- Name: email_provider_config id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email_provider_config ALTER COLUMN id SET DEFAULT nextval('public.email_provider_config_id_seq'::regclass);


--
-- Name: nas id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas ALTER COLUMN id SET DEFAULT nextval('public.nas_id_seq'::regclass);


--
-- Name: radacct radacctid; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radacct ALTER COLUMN radacctid SET DEFAULT nextval('public.radacct_radacctid_seq'::regclass);


--
-- Name: radcheck id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radcheck ALTER COLUMN id SET DEFAULT nextval('public.radcheck_id_seq'::regclass);


--
-- Name: radcheck_delete_audit id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.radcheck_delete_audit ALTER COLUMN id SET DEFAULT nextval('public.radcheck_delete_audit_id_seq'::regclass);


--
-- Name: radgroupcheck id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radgroupcheck ALTER COLUMN id SET DEFAULT nextval('public.radgroupcheck_id_seq'::regclass);


--
-- Name: radgroupreply id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radgroupreply ALTER COLUMN id SET DEFAULT nextval('public.radgroupreply_id_seq'::regclass);


--
-- Name: radpostauth id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radpostauth ALTER COLUMN id SET DEFAULT nextval('public.radpostauth_id_seq'::regclass);


--
-- Name: radreply id; Type: DEFAULT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radreply ALTER COLUMN id SET DEFAULT nextval('public.radreply_id_seq'::regclass);


--
-- Name: system_health id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_health ALTER COLUMN id SET DEFAULT nextval('public.system_health_id_seq'::regclass);


--
-- Name: system_health_alerts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_health_alerts ALTER COLUMN id SET DEFAULT nextval('public.system_health_alerts_id_seq'::regclass);


--
-- Name: verification_codes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_codes ALTER COLUMN id SET DEFAULT nextval('public.verification_codes_id_seq'::regclass);


--
-- Data for Name: _mac_delete_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._mac_delete_log (id, deleted_username, deleted_at, query, app) FROM stdin;
\.


--
-- Data for Name: _radreply_audit; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public._radreply_audit (id, username, attribute, deleted_at, pid, query) FROM stdin;
\.


--
-- Data for Name: admins; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.admins (id, name, email, password_hash, role, is_active, last_login, created_at, updated_at) FROM stdin;
e0556dcb-b203-4e85-b0c4-bd657bddcf62	RumaLink Admin	admin@rumalink.co.ke	$2a$12$lW4s6qSv6dP4ZBV4CMkUq.hwqqCiaphkhsZ6qELmJdG7MwF1axeje	superadmin	t	2026-08-01 11:20:27.234121+00	2026-05-24 08:18:35.982073+00	2026-05-24 08:18:35.982073+00
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.audit_logs (id, actor_type, actor_id, action, resource_type, resource_id, changes, ip_address, user_agent, created_at) FROM stdin;
\.


--
-- Data for Name: commissions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.commissions (id, isp_id, payment_id, amount, rate, period_month, period_year, is_settled, settled_at, created_at) FROM stdin;
65cca3cf-eeda-4f5f-8f88-4f30b1f0f07a	15c14766-aa02-4e61-be85-41b79c3ffe85	8dc76f51-bccf-4d51-8369-cca7c8f75e8a	0.15	0.0300	\N	\N	f	\N	2026-07-31 18:42:00.091485+00
de58efa1-e25f-4c08-90fe-402b47eeb7e4	15c14766-aa02-4e61-be85-41b79c3ffe85	990e2277-2755-4c33-a046-9fa57038ff9a	0.15	0.0300	\N	\N	f	\N	2026-07-31 19:09:00.799299+00
96134214-e286-41c0-854b-29bc25630c04	15c14766-aa02-4e61-be85-41b79c3ffe85	e25b8ef9-ddba-4006-9a81-606bbe3a091c	0.15	0.0300	\N	\N	f	\N	2026-08-01 04:24:00.60653+00
ac4c4d5a-8b24-402e-aba0-1bc5d414aa72	15c14766-aa02-4e61-be85-41b79c3ffe85	1f82a039-1d31-4600-8eac-7d1ca0f83fb2	0.15	0.0300	\N	\N	f	\N	2026-08-01 06:06:00.225581+00
1925a60e-8b9b-4cba-ba7e-f6aae5505864	15c14766-aa02-4e61-be85-41b79c3ffe85	210de0e7-ee63-421b-8090-d5ddecfae32c	0.15	0.0300	\N	\N	f	\N	2026-08-01 06:20:00.675229+00
8253aa46-fd46-42ff-8cb0-fae643fada9f	15c14766-aa02-4e61-be85-41b79c3ffe85	a7d91802-3dd9-4ae0-b4d4-90e0cde3231d	0.15	0.0300	\N	\N	f	\N	2026-08-01 06:43:00.375539+00
\.


--
-- Data for Name: email_provider_config; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.email_provider_config (id, provider, smtp_host, smtp_port, smtp_secure, smtp_user, smtp_pass, from_email, from_name, is_active, updated_at, logo_url, logo_bg) FROM stdin;
1	resend	smtp.resend.com	465	t	resend	re_GC6FvMH6_YDoRrQeYEbwRxjrGaAyPW3DB	noreply@rumalinkenterprise.online	RumaLink Enterprise	t	2026-07-26 05:42:41.484707+00	https://rumalinkenterprise.online/logo.png	#262d37
\.


--
-- Data for Name: hotspot_bound_devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hotspot_bound_devices (id, isp_id, name, mac_address, buyer_phone, active_voucher_id, bound_ip, package_id, expires_at, is_bound, created_at, updated_at, usage_base_in, usage_base_out, last_ctr_in, last_ctr_out) FROM stdin;
b72979b4-cfe8-4ac8-94ce-b45a180127a1	15c14766-aa02-4e61-be85-41b79c3ffe85	Gytv	BC:2B:02:3A:7F:7C	\N	0869c3be-bca3-4cac-a3c7-f3848539fdcb	\N	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	2026-08-01 07:42:50.257958+00	f	2026-08-01 06:41:26.136525+00	2026-08-01 07:43:03.396763+00	30665891	19917562	28406182	21950884
\.


--
-- Data for Name: hotspot_packages; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_packages (id, isp_id, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, created_at, updated_at) FROM stdin;
c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	1 Hour	\N	5.00	1	5	5	\N	1		t	2026-07-31 18:28:53.913656+00	2026-07-31 18:28:53.913656+00
\.


--
-- Data for Name: hotspot_sessions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_sessions (id, isp_id, voucher_id, nas_id, radius_session_id, mac_address, ip_address, nas_ip, bytes_downloaded, bytes_uploaded, session_time_seconds, status, started_at, ended_at, terminate_cause) FROM stdin;
\.


--
-- Data for Name: hotspot_vouchers; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_vouchers (id, isp_id, package_id, nas_id, code, batch_id, status, used_by_mac, used_by_ip, used_at, expires_at, bytes_downloaded, bytes_uploaded, time_used_seconds, is_paid, amount_paid, payment_method, payment_reference, created_at, updated_at, buyer_phone, sms_sent, expiry_sms_sent, payment_id, is_test, password, is_tv, tv_mac, created_by_isp, import_batch, purchased_by_mac) FROM stdin;
4ed702a9-68a4-409f-bfa1-ce4cfe9dc375	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B18	\N	expired	\N	\N	\N	2026-08-01 00:43:10+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.659523+00	2026-08-01 00:44:00.772451+00	0724733806	f	f	\N	f	dyd3y3	f	\N	t	imp_1785536520498	\N
f94239e1-5ca3-45c9-9b9a-67a3781a6355	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B28	\N	expired	\N	\N	\N	2026-08-01 02:09:33+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.741333+00	2026-08-01 02:10:00.603713+00	0743522155	f	f	\N	f	ae4bf6	f	\N	t	imp_1785536520498	\N
10f06897-9bbc-4c2b-aba3-7c6e83a3bc44	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B24	\N	expired	\N	\N	\N	2026-08-01 02:13:10+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.706946+00	2026-08-01 02:14:00.742478+00	0741086757	f	f	\N	f	22286y	f	\N	t	imp_1785536520498	\N
056596d0-d4fa-4a12-b357-81f1fd744f76	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B9	\N	expired	\N	\N	\N	2026-08-01 04:07:18+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.569108+00	2026-08-01 04:08:00.562132+00	0743205112	f	f	\N	f	fcy3y5	f	\N	t	imp_1785536520498	\N
40ec7d4c-afa8-47aa-93bd-b7dec563cef0	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B25	\N	expired	\N	\N	\N	2026-08-01 04:21:25+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.715786+00	2026-08-01 04:22:00.533843+00	0111638647	f	f	\N	f	525244	f	\N	t	imp_1785536520498	\N
c1020b71-fc83-477c-bf83-5a049b610206	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B3	\N	active	\N	\N	\N	2026-08-03 08:41:56+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.50998+00	2026-07-31 22:22:00.50998+00	0704101213	f	f	\N	f	85ydb9	f	\N	t	imp_1785536520498	\N
9bd1ac9a-514a-4566-9b06-82df43b14691	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B4	\N	active	\N	\N	\N	2026-08-06 15:51:06+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.518003+00	2026-07-31 22:22:00.518003+00	0704101226	f	f	\N	f	fyd7ab	f	\N	t	imp_1785536520498	\N
7bd17a01-44b0-42ba-b6b1-128379bbd01d	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B13	\N	active	\N	\N	\N	2026-08-01 16:46:16+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.608746+00	2026-07-31 22:22:00.608746+00	0704714570	f	f	\N	f	6bf2ce	f	\N	t	imp_1785536520498	\N
359c9721-efab-4c15-ac54-b6e1da7e0c56	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B15	\N	active	\N	\N	\N	2026-08-01 15:06:19+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.631696+00	2026-07-31 22:22:00.631696+00	0112404681	f	f	\N	f	ddff5c	f	\N	t	imp_1785536520498	\N
8230a41e-fa4b-4c7e-a4e3-6a213359288b	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B16	\N	active	\N	\N	\N	2026-08-01 17:10:32+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.640282+00	2026-07-31 22:22:00.640282+00	0743522155	f	f	\N	f	f82xe6	f	\N	t	imp_1785536520498	\N
a50749b1-7eb0-48d6-9016-e5624ee6094f	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B22	\N	active	\N	\N	\N	2026-08-01 16:25:47+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.691341+00	2026-07-31 22:22:00.691341+00	0745718578	f	f	\N	f	b6ee7x	f	\N	t	imp_1785536520498	\N
81a27012-2177-49a7-bf36-bb59e2e3fec6	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B27	\N	active	\N	\N	\N	2026-08-01 15:51:57+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.734283+00	2026-07-31 22:22:00.734283+00	\N	f	f	\N	f	3y7b8d	f	\N	t	imp_1785536520498	\N
c65ceec3-f838-4e19-886c-3a424c0e4764	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B17	\N	expired	\N	\N	\N	2026-07-31 22:59:39+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.64717+00	2026-07-31 23:00:00.624984+00	0795429825	f	f	\N	f	7788bx	f	\N	t	imp_1785536520498	\N
9296145f-e616-443b-87ac-3cbeca2f4f4e	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B23	\N	expired	\N	\N	\N	2026-07-31 23:06:53+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.698434+00	2026-07-31 23:07:00.818264+00	0729295508	f	f	\N	f	5d677y	f	\N	t	imp_1785536520498	\N
968c207b-13c9-40b8-87dc-4693c6d9568f	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B21	\N	expired	\N	\N	\N	2026-07-31 23:08:44+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.684005+00	2026-07-31 23:09:00.879541+00	0724616876	f	f	\N	f	e3fdfa	f	\N	t	imp_1785536520498	\N
4c95d469-dca6-438d-8c45-7e55ed89db9d	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B30	\N	expired	\N	\N	\N	2026-08-01 05:23:00.022342+00	0	0	0	t	\N	\N	\N	2026-08-01 04:23:01.173626+00	2026-08-01 05:23:03.278766+00	254796829688	f	f	e25b8ef9-ddba-4006-9a81-606bbe3a091c	f	yx6dxa	f	\N	f	\N	\N
53367cdc-166b-4921-b93b-46fcb1e8acd1	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B29	\N	expired	\N	\N	\N	2026-08-01 05:23:00.022342+00	0	0	0	t	\N	\N	\N	2026-08-01 04:23:01.166499+00	2026-08-01 05:23:04.619794+00	254796829688	f	f	e25b8ef9-ddba-4006-9a81-606bbe3a091c	f	3ee53e	f	\N	f	\N	\N
6090a93f-dadd-4593-8659-202b8208772a	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B11	\N	expired	\N	\N	\N	2026-08-01 04:38:35+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.590969+00	2026-08-01 04:39:00.074235+00	0758663217	f	f	\N	f	46535y	f	\N	t	imp_1785536520498	\N
b506e009-2b8f-4f34-8bbc-66e5bbe17bee	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B5	\N	expired	\N	\N	\N	2026-08-01 04:43:30+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.52819+00	2026-08-01 04:44:00.202503+00	0727134277	f	f	\N	f	f4d779	f	\N	t	imp_1785536520498	\N
1401ae9e-f9e9-4e0e-9ee9-34149a6dcb6f	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B10	\N	expired	\N	\N	\N	2026-08-01 04:56:29+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.578075+00	2026-08-01 04:57:00.642239+00	0716522182	f	f	\N	f	f3x3c6	f	\N	t	imp_1785536520498	\N
107168c0-0f47-45ff-8b61-24de44ea39cc	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B14	\N	expired	\N	\N	\N	2026-08-01 04:56:36+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.623519+00	2026-08-01 04:57:00.642239+00	0748894472	f	f	\N	f	795542	f	\N	t	imp_1785536520498	\N
bfbb9f47-8a61-4597-a32a-d9d675ed9ac7	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B2	\N	expired	\N	\N	\N	2026-08-01 05:22:22+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.500483+00	2026-08-01 05:23:00.855237+00	0796829688	f	f	\N	f	byex9x	f	\N	t	imp_1785536520498	\N
c6a3e005-46b8-469c-babc-3f1ad5adcf65	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B19	\N	expired	\N	\N	\N	2026-08-01 05:33:03+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.669375+00	2026-08-01 05:34:00.280907+00	0722962879	f	f	\N	f	79yaab	f	\N	t	imp_1785536520498	\N
9b14e9c9-6901-41f6-9f94-1726e93be54a	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B8	\N	expired	\N	\N	\N	2026-08-01 05:52:12+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.558473+00	2026-08-01 05:53:00.855718+00	0799512294	f	f	\N	f	72xd69	f	\N	t	imp_1785536520498	\N
69c266a2-21bd-41e1-89c3-b21165294509	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B26	\N	expired	\N	\N	\N	2026-08-01 05:58:00+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.727113+00	2026-08-01 05:58:00.98327+00	0714649570	f	f	\N	f	a37d6f	f	\N	t	imp_1785536520498	\N
4e92d656-7453-4e71-a528-8d145889cfcb	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B12	\N	expired	\N	\N	\N	2026-08-01 09:27:06+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.59836+00	2026-08-01 09:28:00.090404+00	0797188355	f	f	\N	f	ca9ayy	f	\N	t	imp_1785536520498	\N
8fedeb6a-5196-4a2d-b194-e94721833099	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B6	\N	expired	\N	\N	\N	2026-08-01 06:36:04+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.535957+00	2026-08-01 06:37:00.156485+00	0748296914	f	f	\N	f	5dcae3	f	\N	t	imp_1785536520498	\N
ca5eda88-aca7-42e0-bc24-21fa7cc628d7	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B1	\N	expired	\N	\N	\N	2026-08-01 06:38:37.781224+00	0	0	0	t	\N	\N	\N	2026-07-31 18:41:28.712062+00	2026-08-01 06:38:37.781224+00	254740258495	f	f	1f82a039-1d31-4600-8eac-7d1ca0f83fb2	f	c5ye9c	f	\N	f	\N	\N
6793e8e1-fb6a-41f4-8b96-63b544f98a09	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B20	\N	expired	\N	\N	\N	2026-08-01 06:51:22+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.676672+00	2026-08-01 06:52:00.789854+00	0740887780	f	f	\N	f	f89b4e	f	\N	t	imp_1785536520498	\N
6df64fb1-9169-45aa-8eda-90cc296b0c78	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B7	\N	expired	\N	\N	\N	2026-08-01 07:10:57+00	0	0	0	f	\N	\N	\N	2026-07-31 22:22:00.54949+00	2026-08-01 07:11:00.268887+00	0797526769	f	f	\N	f	d63a73	f	\N	t	imp_1785536520498	\N
9e9ad075-91c2-4d71-9530-db5c1159a003	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B31	\N	expired	\N	\N	\N	2026-08-01 07:19:17.847786+00	0	0	0	t	\N	\N	\N	2026-08-01 06:19:20.046095+00	2026-08-01 07:20:00.453798+00	254117195942	f	f	210de0e7-ee63-421b-8090-d5ddecfae32c	f	y9fce4	f	\N	f	\N	\N
0869c3be-bca3-4cac-a3c7-f3848539fdcb	15c14766-aa02-4e61-be85-41b79c3ffe85	c2e1bde5-d1b1-4a69-b4ad-88a1c64469b6	\N	B32	\N	expired	BC:2B:02:3A:7F:7C	\N	\N	2026-08-01 07:42:50.257958+00	0	0	0	t	\N	\N	\N	2026-08-01 06:42:52.804393+00	2026-08-01 07:43:00.220262+00	254740258495	f	f	a7d91802-3dd9-4ae0-b4d4-90e0cde3231d	f	2bf82y	t	BC:2B:02:3A:7F:7C	f	\N	BC:2B:02:3A:7F:7C
\.


--
-- Data for Name: intasend_withdrawals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.intasend_withdrawals (id, isp_id, method, destination, gross_amount, fee_amount, net_amount, below_threshold, status, intasend_ref, intasend_state, failure_reason, balance_before, balance_after, metadata, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: isp_captive_portal; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_captive_portal (id, isp_id, template, primary_color, secondary_color, logo_url, welcome_title, welcome_subtitle, bg_image_url, show_logo, show_powered_by, custom_css, updated_at, support_number, support_label, enable_tv_mode, notif_enabled, notif_title, notif_message, notif_severity, notif_start, notif_end, media_enabled, media_type, media_video_url, media_images, media_interval, media_fit) FROM stdin;
\.


--
-- Data for Name: isp_payment_methods; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_payment_methods (id, isp_id, method_type, label, shortcode, consumer_key, consumer_secret, passkey, is_sandbox, use_admin_credentials, till_number, paybill_number, account_reference, bank_name, account_name, account_number, branch, forward_to_type, forward_to_number, forward_to_name, is_active, is_verified, is_default, created_at, updated_at, provider, environment) FROM stdin;
298b90a6-f9d7-4de2-8895-6341697ac271	15c14766-aa02-4e61-be85-41b79c3ffe85	mpesa_stk	4322307	4322307	7V4yYILZxVLaYRalxSX7vLNKARpAItO9YwOzlA0pCCQ4KZQ0	b0eWBg6Cv0G558cMO6OhAbAKrJJ5wDvMAybO9axDEB1ZVastiVAAjh2HKwrz0VRw	3317f5d8845fbe32c8e8435e1b79934d36ae1c303f9383b5d8a35ac36d4720b6	f	f	\N	\N	\N	\N	\N	\N	\N	till	\N	\N	t	f	t	2026-07-31 18:40:46.679362+00	2026-07-31 18:40:46.679362+00	\N	production
\.


--
-- Data for Name: isp_platform_invoices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_platform_invoices (id, isp_id, period_month, period_year, pppoe_user_count, amount_per_user, total_amount, status, due_date, paid_at, created_at, invoice_number, invoice_type, payment_id, hotspot_revenue, hotspot_fee, hotspot_rate, pppoe_fee, window_start, window_end, period_expires_at) FROM stdin;
9f20ac7c-b6cc-470b-8656-29f8f9645374	15c14766-aa02-4e61-be85-41b79c3ffe85	8	2026	23	32.25	741.75	pending	2026-08-08	\N	2026-08-01 08:00:00.680167+00	\N	pppoe_monthly	\N	0.00	0.00	0.0300	0.00	\N	\N	\N
\.


--
-- Data for Name: isp_transactions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_transactions (id, isp_id, type, amount, balance_before, balance_after, description, reference_id, created_at) FROM stdin;
9c5f3513-063f-4694-82c0-d9d7e204eb9e	15c14766-aa02-4e61-be85-41b79c3ffe85	payment	5.00	\N	5.00	IntaSend payment - UGV1313N78	8dc76f51-bccf-4d51-8369-cca7c8f75e8a	2026-07-31 18:42:00.130247+00
9cc8790d-3a81-41cb-8d4c-082215b0caf7	15c14766-aa02-4e61-be85-41b79c3ffe85	payment	5.00	\N	10.00	IntaSend payment - UGV1313SO9	990e2277-2755-4c33-a046-9fa57038ff9a	2026-07-31 19:09:00.803889+00
e1d31191-de75-4ce6-9271-eb75450c5c4c	15c14766-aa02-4e61-be85-41b79c3ffe85	payment	5.00	\N	15.00	IntaSend payment - UH1JK11WU4	e25b8ef9-ddba-4006-9a81-606bbe3a091c	2026-08-01 04:24:00.622226+00
aa52deaf-dc89-4f3e-8f0c-51554b4af324	15c14766-aa02-4e61-be85-41b79c3ffe85	payment	5.00	\N	20.00	IntaSend payment - UH11314F3A	1f82a039-1d31-4600-8eac-7d1ca0f83fb2	2026-08-01 06:06:00.240035+00
018de468-3e91-43a2-bd02-bee7a37299af	15c14766-aa02-4e61-be85-41b79c3ffe85	payment	5.00	\N	25.00	IntaSend payment - UH1C811RP5	210de0e7-ee63-421b-8090-d5ddecfae32c	2026-08-01 06:20:00.684345+00
6a397b35-26bb-41a1-8bb9-20e642dcdab9	15c14766-aa02-4e61-be85-41b79c3ffe85	payment	5.00	\N	30.00	IntaSend payment - UH11314QE7	a7d91802-3dd9-4ae0-b4d4-90e0cde3231d	2026-08-01 06:43:00.382221+00
\.


--
-- Data for Name: isps; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isps (id, company_name, owner_name, email, phone, password_hash, plan_type, status, county, town, address, api_key, api_secret, webhook_url, wallet_balance, commission_rate, pppoe_rate_per_user, total_earned, total_commission_paid, sms_gateway, sms_api_key, sms_sender_id, logo_url, timezone, currency, email_verified, email_verify_token, password_reset_token, password_reset_expires, trial_ends_at, last_login, created_at, updated_at, sms_username, sms_partner_id, sms_api_secret, support_number, hotspot_counter, subscription_started_at, license_expires_at, billing_window_start, license_status, billing_exempt, sms_balance, phone_verified, phone_verified_at, email_verified_at) FROM stdin;
15c14766-aa02-4e61-be85-41b79c3ffe85	bonte	esther	rumalinkenterprise@gmail.com	0704994652	$2a$12$nlDZVgi5.ZlR6Bj.RQMpfu4ltwaO1JYD8a7ScxxgwoHrFjZYrk9ja	both	active	Nairobi	Nairobi	\N	b33ee688-2130-4270-aa0b-df6c52ebefd5	d82ac98c81202f18eaf5c42b2e93b5c3451fd97b304522ca697d30599c2998ba	\N	30.00	0.0300	32.25	30.00	0.90	\N	\N	\N	\N	Africa/Nairobi	KES	t	\N	\N	\N	2026-08-30 18:23:18.907354+00	2026-08-01 10:43:43.774841+00	2026-07-31 18:23:18.907354+00	2026-07-31 18:24:24.01628+00	\N	\N	\N	\N	13	\N	\N	\N	trial	f	40.0000	t	2026-07-31 18:24:24.01628+00	2026-07-31 18:23:38.392229+00
\.


--
-- Data for Name: mac_auth_cache; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.mac_auth_cache (id, mac_address, isp_id, package_id, authorized_at, expires_at, is_active, created_at) FROM stdin;
\.


--
-- Data for Name: mpesa_configs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.mpesa_configs (id, isp_id, shortcode, consumer_key, consumer_secret, passkey, callback_url, is_sandbox, is_active, created_at, updated_at, is_admin_config) FROM stdin;
\.


--
-- Data for Name: mpesa_transactions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.mpesa_transactions (id, isp_id, payment_id, checkout_request_id, merchant_request_id, result_code, result_desc, amount, mpesa_receipt, phone, transaction_date, status, raw_callback, created_at) FROM stdin;
71fd68cd-d3c3-4ac1-8736-616b0e53b5ac	15c14766-aa02-4e61-be85-41b79c3ffe85	8dc76f51-bccf-4d51-8369-cca7c8f75e8a	ws_CO_31072026214128643740258495	782d-4443-86ce-dad3d66153935514162	\N	\N	5.00	UGV1313N78	254740258495	2026-07-31 18:41:41.074318+00	completed	\N	2026-07-31 18:41:28.706242+00
73b79988-6bf6-4b80-9274-c7cdd9503dfe	15c14766-aa02-4e61-be85-41b79c3ffe85	990e2277-2755-4c33-a046-9fa57038ff9a	ws_CO_31072026220832248740258495	9f15-498f-8d75-f1ac6baed10125254852	\N	\N	5.00	UGV1313SO9	254740258495	2026-07-31 19:08:42.048294+00	completed	\N	2026-07-31 19:08:32.122261+00
aa7f9c63-c3b3-49b0-aac0-aba7093bdc81	15c14766-aa02-4e61-be85-41b79c3ffe85	e25b8ef9-ddba-4006-9a81-606bbe3a091c	ws_CO_01082026072248356796829688	3d57-4feb-a16b-cbb513bab6ed20427758	\N	\N	5.00	UH1JK11WU4	254796829688	2026-08-01 04:23:00.033041+00	completed	\N	2026-08-01 04:22:48.763787+00
39402a30-a575-4f19-b0cb-80e7e45c30de	15c14766-aa02-4e61-be85-41b79c3ffe85	1f82a039-1d31-4600-8eac-7d1ca0f83fb2	ws_CO_01082026090541250740258495	2225-4750-878c-a6bb3717aa6c6122119	\N	\N	5.00	UH11314F3A	254740258495	2026-08-01 06:05:51.78816+00	completed	\N	2026-08-01 06:05:42.070768+00
3d0831cc-65fe-439e-a6ab-03cf7628deab	15c14766-aa02-4e61-be85-41b79c3ffe85	a6d77fe2-2999-4d0c-9952-c8efb1868c7d	ws_CO_01082026091720476117195942	0e40-41bd-bd16-3ef67d42a821592207	\N	\N	5.00	\N	254117195942	\N	pending	\N	2026-08-01 06:17:20.642947+00
bb52e548-c1d2-4862-b2bc-df005d5c726a	15c14766-aa02-4e61-be85-41b79c3ffe85	210de0e7-ee63-421b-8090-d5ddecfae32c	ws_CO_01082026091855496117195942	e6f5-4b3d-93ed-bb868f4972bd5621222	\N	\N	5.00	UH1C811RP5	254117195942	2026-08-01 06:19:17.849966+00	completed	\N	2026-08-01 06:18:55.490132+00
57a2c147-84a6-442d-95c4-11f85a68e316	15c14766-aa02-4e61-be85-41b79c3ffe85	a7d91802-3dd9-4ae0-b4d4-90e0cde3231d	ws_CO_01082026094231434740258495	4685-4c53-80cd-c502b1b6f1dd19158365	\N	\N	5.00	UH11314QE7	254740258495	2026-08-01 06:42:50.259834+00	completed	\N	2026-08-01 06:42:31.533762+00
\.


--
-- Data for Name: nas; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas (id, nasname, shortname, type, ports, secret, server, community, description) FROM stdin;
1	10.8.0.2	DandoraP3	mikrotik	\N	RMLC220AE224D174260	\N	\N	RumaLink auto-sync
\.


--
-- Data for Name: nas_devices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_devices (id, isp_id, name, description, nas_ip, nas_port, secret, provision_token, provision_url, is_provisioned, provisioned_at, mikrotik_identity, mikrotik_version, mikrotik_board, mikrotik_mac, wan_ip, is_online, last_seen, hotspot_enabled, pppoe_enabled, hotspot_profile, pppoe_pool, winbox_port, created_at, updated_at, antishare_enabled, antishare_max_devices, bridged_ports, bridge_ports, hotspot_interface, pppoe_interface, gateway_ip, ip_pool_start, ip_pool_end, dns_primary, dns_secondary, hotspot_network, hotspot_gateway, hotspot_pool_start, hotspot_pool_end, mikrotik_api_user, mikrotik_api_password, remote_winbox_url, provision_step, cpu_load, memory_used_mb, memory_total_mb, disk_used_mb, disk_total_mb, uptime_seconds, wan_interface, available_interfaces, wireguard_private_key, wireguard_public_key, wireguard_ip, radius_secret, winbox_proxy_port, isp_link_status, isp_link_changed_at, isp_link_last_checked, isp_link_consecutive_failures, isp_link_notifications_enabled, multi_wan_mode, wan1_interface, wan1_gateway, wan1_ping_target, wan2_interface, wan2_gateway, wan2_ping_target, multi_wan_check_interval, multi_wan_fail_threshold, lb_weight_wan1, pcc_mode, multi_wan_applied_at, wan_quality_enabled, wan_quality_latency_ms, wan_quality_jitter_ms, wan_quality_loss_pct, wan_quality_trip_count, wan_quality_recover_count, wan_type, wan_pppoe_user, wan_pppoe_pass, wan_static_ip, wan_static_gw, wan_selected, wan_quality_min_mbps) FROM stdin;
1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	DandoraP3	\N	\N	3799	RMLC220AE224D174260	79e871bf-8035-40da-85e4-9cfcad6686a1	https://rumalinkenterprise.online/api/provision/79e871bf-8035-40da-85e4-9cfcad6686a1	t	2026-07-31 18:27:06.340122+00	MikroTik	7.19.6 (stable)	RB951Ui-2HnD	pending	\N	t	2026-08-01 11:19:25.14945+00	t	t	\N	\N	20001	2026-07-31 18:26:49.364844+00	2026-08-01 11:19:25.14945+00	f	1	["ether2", "ether3", "ether4", "wlan1"]	ether3,ether4,ether5	bridge1	ether1	192.168.88.1	192.168.88.10	192.168.88.254	8.8.8.8	8.8.4.4	10.100.0.0/24	10.100.0.1	10.100.0.10	10.100.0.250	rl_1cb9b8d3	e8fab5da-f65	rumalinkenterprise.online:20001	configured	9	62	128	22	128	0	ether2	ether1,ether2,ether3,ether4,ether5	gE5K8PY8YWqiXAmRjsfeydmPY6/nlFJWqYe7Vzr2yUY=	2A7Rmajf0AJY1cAzq2GvUk+dfjjQGQ0CTA+WGBANZBE=	10.8.0.2	RMLC220AE224D174260	\N	up	2026-08-01 11:17:04.255+00	2026-08-01 11:20:02.671+00	0	t	failover	\N	\N	8.8.8.8	\N	\N	1.1.1.1	10	3	50	both-addresses	2026-08-01 06:13:22.935185+00	t	150	60	2	4	4	pppoe	mikrotiktest2	mikrotik2541028	\N	\N	t	3
\.


--
-- Data for Name: nas_events; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_events (id, nas_id, isp_id, event_type, message, created_at) FROM stdin;
fcdc1c9e-fc95-4d3a-be0f-d6be3aee8397	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	provisioned	Config imported	2026-07-31 18:27:06.372263+00
8b2f9e6e-1c72-4cf7-b652-feffb2ff958b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:14:20.059626+00
923bf0b3-2da1-42c2-a1c9-7f4e952c98dc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:14:23.734504+00
6cbdcb46-f099-4022-82ac-945c9b97b843	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:15:08.695051+00
e7a8978c-b9c0-4f5e-920d-a115ea53aa8a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:15:42.935275+00
ef3cf4a3-8dd1-4d47-a7c8-d3654ff4f894	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:16:16.994484+00
be7f7e58-0d83-4dea-ba36-eabba3254181	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:16:57.389791+00
691b6b27-0c28-4d86-823b-024038bc47ee	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:17:39.711705+00
8d54e227-bdfb-4922-ad57-f9bbfcb7e98a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:18:23.552354+00
6fd61cf2-b1a1-458e-9bfe-b5777ddbb8e2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:18:57.428228+00
71d246da-0d9d-4e78-a49e-aff4d663a59e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:19:29.489133+00
649b95a2-db8c-4f32-9a85-c8005b15cf1a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:19:57.757869+00
63155b50-5cfd-4465-b6b7-701c883260f1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:20:29.013413+00
3297f10e-6560-483a-b63b-9467a22a7b3e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:20:57.661844+00
7adbfbc1-3b3a-4d95-941a-9401164aa3bc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:21:29.798501+00
328d9fe0-cd76-46d7-abf4-af7222db5126	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:21:57.870693+00
17bcf4dc-65dc-4160-aa01-406ae7b9eb26	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:22:31.222689+00
130f19a6-9732-4dd4-b7db-f18b515d4e41	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:23:17.199268+00
5fb64201-5ef2-47a2-9d3a-d9946878430b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:23:58.331684+00
6e4f661b-f31d-4842-8f44-344b6ab6dcb1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:24:33.327757+00
ae56a1bd-362b-41ba-b1d1-84e36fccdad4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:25:17.272153+00
f4532356-907a-4d8f-98ba-f15a21a143ec	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:25:58.041511+00
e17a581c-0c5e-4435-b053-a2214d12bb66	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:26:39.383893+00
c8c7a150-05ec-43ec-b185-a56b31e751fe	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:27:15.251854+00
3c1ecd5b-db28-464b-a396-175b25746f51	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:27:52.322323+00
aa4f8eed-4f88-4307-87e9-1ce487a3d76b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:28:31.474444+00
3734899f-61fe-49c6-88d2-70290c8bc57f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:29:17.352166+00
47cad2ca-ecbb-4c9f-92a4-672b4493b239	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:29:58.169385+00
2511833b-4549-4e5e-9132-3189b958d944	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:30:30.130019+00
fadfd321-d948-4868-aed8-cd2589604750	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:30:58.135453+00
d639b8a1-b217-4a96-a0ab-bcf0a3b3e79b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:31:31.596576+00
15035c99-b260-40e0-b437-10b88142eeab	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:32:17.079455+00
2278c67e-b10a-4352-b788-37aafdee9f01	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:32:58.340098+00
efa9ced6-279c-4d16-8c03-f5f44c6d1601	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:33:30.571959+00
a410285d-459b-40c1-94e3-00886f4e17f8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:34:23.625997+00
5ca30e67-ea85-45d5-99ff-37b2928d2590	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:34:59.3721+00
c0f472cd-887d-4d2b-a8ac-adfbaa582a78	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:35:39.801274+00
491c1014-9862-4555-8ded-16b91c46afbd	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:36:16.618055+00
8b08e772-3317-4941-be41-f46f5d027867	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:36:57.996889+00
468d8966-1e48-4c70-9ef1-bb5c365736f7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:37:29.857499+00
1e0da6b2-213e-4a2b-bd8e-4477ca2fe44c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:37:56.348412+00
83767b07-3602-4829-8959-6c571693b84e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:38:28.395741+00
eabd0833-2f30-4c57-847f-2f297e91e21d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:38:58.082222+00
65698cc7-8942-4739-ab59-3a25007a3265	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:39:30.418892+00
3397873f-3c35-4195-aebf-141a831a17a8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:40:16.367858+00
ae0afbd0-8fa9-47cd-bbf4-ef6af2c11b82	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:40:57.484611+00
da83a3d3-0964-4140-8ca2-6574ec95dcd2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:41:29.989942+00
b46e265b-b168-42a5-8cf3-1de9ec54ed1f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:41:56.358869+00
f04c8a38-1cf7-400e-a4d6-3402205ca843	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:42:39.569742+00
26839b95-1487-48b7-a3d2-6c587dabaed2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:43:13.471885+00
d32cb4b4-1f05-4cbe-92a7-e4831b20a973	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:43:42.717786+00
94e245f0-4de8-438d-9be2-a922908178b2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:44:16.956737+00
e6ded251-7e1f-47bf-b7d8-25cdb901d3f3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:44:56.642577+00
be1b741e-4ade-4233-b17f-d5e12962f4d8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:45:47.55634+00
43386555-cf29-4081-9931-7ef322bc45a6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:46:20.884865+00
67acddd3-3c98-45a2-b78d-c8f8d85ae2ef	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:46:47.74495+00
e11c4463-9903-4200-bddd-891a1090563e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:47:19.915713+00
3371caba-ab65-4083-a759-b86717b1b968	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:47:47.456495+00
46feeb6d-6290-4c40-ae80-9a6162157530	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:48:19.376529+00
617ff298-2f85-4491-a92c-4216510d66a0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:48:47.760818+00
45aab18b-62f4-4712-b364-c22abe17666d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:49:19.445747+00
7d1a187a-d8eb-4f88-8644-ff0a06fe206c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:49:49.129748+00
133c21a4-fde2-4840-85af-e37d2174637d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:50:20.482542+00
08c93452-1f71-42bc-92cf-4d2709c86d1c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:50:49.095848+00
7e642181-c0ac-435a-bc4b-757e40d68068	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:51:20.865039+00
5debbe9c-73e9-4f3f-bcea-448301a037b7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:51:59.386051+00
5a5721f7-5c16-43df-ab42-6eeb470b91c8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:52:30.352099+00
c6d5c6dc-e377-4a09-ab87-8b470e93d970	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:52:58.543544+00
68677a92-ec41-4971-81fd-5c3768d882ce	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:53:31.689241+00
e97d32c7-1355-44a5-8fad-f135a4f14070	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:54:16.859781+00
6622d5a8-b969-4adc-8482-a3fe0de8d9be	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:54:58.752493+00
221579bd-286c-48b3-bc92-ff0d099d4e47	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:55:44.002577+00
d4431578-ccb2-4923-bc7b-0c088136fa9a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:56:18.96769+00
d392b2f0-d1e0-4d5f-b752-73bbc15050ab	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:56:59.449263+00
5232086d-6bde-4acc-b831-039ee1afdbaa	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:57:30.363586+00
47690248-29f6-4c71-9f7e-f7467e7fc0a6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:57:58.331559+00
7a726657-3cc7-493a-be75-0d2d0d713be2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:58:31.240235+00
6d87579f-b8ed-476a-bd24-072541f3a506	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:59:17.527812+00
08907803-1c24-4ac3-a13b-91329cf2dc05	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 06:59:59.063696+00
e49bb3a1-763e-46df-833c-3033a9f10a22	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:00:31.889995+00
44d81bd6-6e80-424f-af83-0306d319166b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:01:16.343043+00
7c5fb174-0769-4d3d-a59c-8de921375ba6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:01:57.950725+00
61777eca-3653-40ec-8978-56c7fdcfd424	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:02:29.781058+00
eb9324cc-e631-41dc-96de-23892b7ebb2c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:02:57.48499+00
6419a351-6c39-4b99-a3dd-b65f7f2e0586	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:03:30.216175+00
93d56adc-9c18-4336-b9a7-e631f2c846bf	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:04:17.238392+00
d345607f-d289-48ce-9ffe-56a0ac7e46f1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:04:57.678293+00
04f177d1-1564-4ee3-ba03-2c9a1387004f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:05:29.852572+00
3165dd6c-92ef-4f7b-ad6a-48e2d457278e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:05:57.845138+00
c0bb8726-5901-4b7c-8e78-74cdc3e64b71	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:06:31.948061+00
cb17a4bd-3ac6-4051-91d3-a52a64805fb3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:07:17.864047+00
1b9c4e3d-aef0-46cf-9715-4af6b82e724e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:07:57.907094+00
b2c8b317-31d7-4df7-b66b-9cab83754048	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:08:29.622057+00
c91913cf-19ca-47f1-9179-e57d290b7130	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:08:57.691019+00
e41d4954-dfcf-4b3c-bdcf-0058fb59f4a0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:09:29.70307+00
0a997d8f-9e57-4098-b8f2-f3afcfa5e2ef	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:09:57.609548+00
bd65def2-c136-443a-a4bc-d1866e465db4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:10:30.203351+00
733524cd-b08f-4bf7-a75b-95e05367e2e6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:11:17.392604+00
06335fe4-1bc7-43d4-a49e-17bbaa90e79c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:11:57.509948+00
6b40aac3-6b73-43d9-aa09-6d0e954d0b58	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:12:29.054486+00
075bf878-8275-493a-a735-fd841d23baf0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:12:57.371569+00
59a469b3-0868-4805-b2c9-f6fd53bb3700	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:13:29.774788+00
919b08b1-a5ba-4b4a-9fb2-cf93194278f4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:13:58.021887+00
41660b0e-bd9c-42d5-8fae-ec94ec5cf61a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:14:29.631177+00
bbbb4850-ee20-425b-8293-d4a7907de06f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:14:57.605501+00
f2150ea0-a23d-480d-94fa-5cb1c41906fd	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:15:31.241397+00
cd31f0bb-3698-4cfe-8211-874ca63d3ef8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:16:17.250463+00
15783de6-ecfd-4459-9f15-7c311e71a97a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:17:00.493554+00
e6f348a9-34d3-4a85-9a62-5f19fa09287f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:17:43.619155+00
cf037048-471b-48b2-ba58-d0af91894a6e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:18:17.333326+00
2ff04e96-6ad8-405b-be0f-ed58afbf1d5a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:18:58.448828+00
140d24b3-fa55-4fe5-a8b0-fcce41079ee3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:19:30.650939+00
6a48dfe1-9f6e-46f4-8102-3d7dbdc1fd38	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:20:17.64525+00
a7a271d6-dd4c-4299-8292-1a04db26ca21	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:20:58.255076+00
89191a7d-52cc-4096-aeec-4cfc8c757df3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:21:30.055628+00
57053a99-1f7a-41ce-9277-21e87b9d5438	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:21:58.00182+00
e2ad7878-5e68-42ea-a824-b1385f4acb9a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:22:58.303145+00
6a415361-7581-42a5-8024-726065d9eed5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:23:29.375609+00
6cd40560-1bac-4410-966e-ff6baa337ea3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:23:57.716895+00
6980942b-8672-4ec3-80b4-6bb26668f6b8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:24:30.471421+00
7bd011fa-a372-436d-86de-f31a49b4df4c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:25:04.54257+00
bea9978a-61e3-43ce-a1ea-8f200cca8ad0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:25:33.102433+00
4f55ca61-02de-4653-aea6-7164dd742cbf	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:26:04.092272+00
3fab2ac0-4296-46e2-98b4-bc89e875787d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:26:32.224225+00
73483ffc-1692-4db2-b8fd-5ae575ebece0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:27:05.105162+00
87f5b2e6-e6da-4dfc-8ff5-bc5ebd0d131f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:27:32.475871+00
76da88cb-523b-4650-8842-5a47bf67ba4b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:28:04.384247+00
48f94825-2ccb-4e32-8749-e9393eecd244	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:28:33.3161+00
cc1c5622-c9f1-4afb-859c-c53cf526f19b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:29:05.568236+00
dce4c84c-896e-40a4-ac1a-5b76e9229b60	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:29:33.915695+00
60af9853-5589-4694-af6e-403564501309	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:30:04.981102+00
f0d71a42-f1ae-4c70-95e3-88bc8800fa20	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:30:32.761179+00
0bd200ca-a230-4f89-b047-44c07bc09126	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:31:05.677434+00
3ddcdab6-ecb2-40e0-8659-ed3f5076783a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:31:33.852364+00
476b501a-6861-4669-8b11-a3c760ff2aa5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:32:18.947065+00
ebd77162-03fe-47b0-a28c-f3ac515a0939	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:32:47.934627+00
55fae4d6-8ede-4afd-8497-4b94aab15ae4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:33:20.658683+00
f601e656-97c2-4b4d-87c9-69121814fd2b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:33:48.767551+00
59a3548c-fef7-4ccb-9d51-107e244ec853	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:34:20.85366+00
3a5bdbb1-bb63-41b5-b58c-aff261eaed6c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:34:49.315267+00
21c6299e-a463-4dc5-8086-b21c6614f7d3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:35:20.999317+00
7c37a64b-c775-4df4-bb02-b81a198001af	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:35:48.850197+00
cf584edf-937a-4603-ab10-950399165dee	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:36:21.087468+00
cbd97c78-41cb-42c9-899e-bf749fc83865	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:36:47.847384+00
9cf10401-c619-4fc1-bb72-08a010bd3c0d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:37:20.322366+00
5b040c3f-2fad-48a2-9be9-e4e1d6d9b7d8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:37:47.12008+00
5f65733a-8640-4ec4-8bfe-bb2bafbff818	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:38:18.800574+00
79fc177d-311d-4503-8ed3-927d429cc4a9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:38:48.047431+00
c679a031-27b1-4a0b-a4b7-f4b2600009f7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:39:18.902934+00
057e4714-7225-419b-9e54-445acd6af67a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:39:47.959883+00
3cc49281-c29c-489c-b79e-81321960e290	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:40:32.825835+00
9cc26cfe-b0d3-4bb4-9561-5b557374530a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:41:16.386825+00
d2595d03-be83-45ec-9711-49b5e69c63e9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:42:10.203058+00
13905eec-2a35-4228-8def-d558020b8f4e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:42:32.114436+00
70b5725e-fba5-4c2f-9203-46f8d278f445	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:43:04.67137+00
c42fe672-b56c-4e31-b07a-8086b05234c3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:43:32.623117+00
16e4d0a3-5302-4901-a628-e2fc6b12df0b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:44:03.767261+00
a0d63f9d-78b6-4168-a0ce-7117bcb12ad5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:44:32.917119+00
bfaac5c3-0dc6-4b51-b764-7b1b863a7397	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:45:04.619087+00
03e41d32-c2ca-49aa-b9a7-e7562f0f6b54	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:45:31.951033+00
fa2f60cb-0f21-41ea-823e-46bd00509886	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:46:04.68416+00
27722a4d-0689-4c9c-8bc2-889abee25da5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:46:32.337538+00
270e4a3f-d7c4-42fb-9c6a-b6694fb6ce6e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:47:04.689292+00
18867d1a-1cc8-43d7-9eb7-7be3aaf0a021	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:47:32.538891+00
c99ebe53-6dbd-4c5e-9f41-c218895fedc7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:48:04.363239+00
03ca5179-ccec-4bd2-bb19-cd7a109901e5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:48:32.798749+00
cf70b261-fca3-40eb-8c51-88bd07c9c52c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:49:05.167497+00
f60d1dd3-ab9a-4d64-87bc-33012e91466b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:49:32.481932+00
57a9e806-d83e-4771-9fb7-4e0b1fa7cd86	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:50:04.245382+00
23c8600e-9bbc-45b3-87b6-f8f68ee56bde	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:50:32.847608+00
02063480-d30c-4d1a-9b43-ebefcf9c49d7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:51:05.235383+00
e55751a1-b5b2-4a44-be97-f8a936cbe382	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:51:32.305163+00
e9295659-ba01-42ea-af84-7200c022e6db	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:52:05.138905+00
f87db560-a746-48c3-9d8d-83e896a88d39	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:52:32.444241+00
5be8ca00-0beb-48d1-952d-6d4dcbe9b125	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:53:04.313567+00
83c2a716-f199-4475-b02d-f69c0a397971	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:53:32.302809+00
b6adccf3-8c96-473a-9b27-763fca37549a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:54:04.052746+00
df92e7ab-d162-4e68-a0ea-a0e4bb6541e4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:54:32.55684+00
ffdf5ed4-6c45-4032-bb3a-f485dc61fe87	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:55:04.176158+00
3fc1d6c1-c2fb-4555-bbde-835b6257d846	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:55:32.502+00
44edb7f1-95b8-4577-a5a8-67d6b087f002	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:56:04.267972+00
f6279af0-3555-45be-98c2-2a345940a0da	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:56:33.369162+00
27fa45b4-d361-4528-a512-9184550dd5a5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:57:04.22757+00
6f32daba-db46-46b3-a58f-5a1294ba4112	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:57:32.753546+00
b7537691-d249-4bf1-92c8-ce2b03989182	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:58:04.289487+00
af7c2197-1a68-4d61-a127-be87f43becae	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:58:32.825466+00
35fe38ca-38ca-4b0a-b8e6-160d7826bb32	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:59:05.361345+00
80b48847-d161-4529-9851-539437699078	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 07:59:32.667641+00
d5ca9d6a-b82d-401e-899e-cb1fa70c6711	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:00:05.130343+00
1e262745-3d68-4ba0-8041-3e8cdaeaad6a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:00:32.917041+00
0263c9ca-761d-42de-9bee-b51211719cbf	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:01:05.41647+00
ab339688-b49f-4d59-b6c5-9c837d1ddfd5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:01:32.90692+00
cb53b890-2670-49ec-ab1e-4d958b389d31	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:02:04.29652+00
5b7b4dce-8c1a-4bfd-8863-a8e3d4923dc0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:02:32.800942+00
79b798c1-1c39-4405-a83e-e78f49250ec7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:03:04.348898+00
d5e49618-0cd1-4cad-8ec3-9b9335f71371	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:03:32.973107+00
dd8eb850-ee7c-4b39-b26e-66bf27844e71	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:04:04.718019+00
fb38ae84-522d-4440-9fae-a3f43cb587a3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:04:32.839265+00
06bf2230-dadd-450f-9a35-49d340bf2b09	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:05:04.487872+00
46e4a597-5045-43ef-b079-fd49163a23be	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:05:32.756978+00
310c41d6-f82f-47f1-bdae-c2f8449a9909	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:06:04.218077+00
98eacaad-af90-4bf9-9e9b-537329dc849f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:06:32.750077+00
17ae2913-cc3b-4585-b2a2-423d446c468e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:07:05.655918+00
3bb5b4ad-5cb1-4682-aef4-b08e4df237b7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:07:33.012549+00
4c97a132-f853-4188-b0d4-87e3e6e520c9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:08:04.594445+00
19d1029e-c0e0-417b-a096-3393ef9d5cbe	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:08:34.05527+00
e8c42f92-8ee2-4b20-870a-049ae45c3c1a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:09:04.614226+00
b0fe71ad-049c-4137-82d8-51e526f7d421	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:09:32.717177+00
fc1d8eab-705b-44d9-a497-d9c477c355ca	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:10:03.890638+00
ea26c8a4-2c65-41f7-afa2-0e828b7e522f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:10:32.795605+00
00760013-141a-4b22-af44-0187d124897c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:11:03.68524+00
49e856cb-a545-4414-aae0-4445acc14afd	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:11:32.848241+00
6196848d-ba43-420a-ba88-010362a224f1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:12:03.894091+00
0a92520b-708f-49e1-b916-24bd3bdd392a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:12:32.605044+00
b7974dfe-1644-47f3-9488-1d7494176dd9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:13:03.649527+00
04f17f06-d5d8-4543-9943-5a101684ec18	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:13:32.116722+00
73a9e8e1-3ea1-46ce-a530-87f49888b668	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:14:04.158461+00
5404ce59-0291-4ffb-a8b9-62a2ebdc5e99	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:14:33.245429+00
5c263c93-232e-44cc-af33-373f4c77d736	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:15:04.273059+00
e8f42f16-f8be-40f6-b624-2ac8f53a98de	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:15:32.191197+00
cb6b38ee-5029-45a3-be2e-842272613aa7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:16:04.013978+00
fe4c66ce-b640-42bc-9311-8c2fa198c9e5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:16:32.354701+00
2539dc4b-dca8-42a5-ad90-82096d5933a1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:17:04.03317+00
24692d18-c9a8-479c-8429-d39d84018bec	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:17:33.214966+00
4a6bceb3-87b7-40f8-9bdf-10cc81f33c24	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:18:04.988444+00
16be98bf-aee2-4236-9a81-695ec839299c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:18:33.395467+00
70c91670-0d97-421e-b96f-3b73d386f426	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:19:05.381531+00
906646b5-2136-4869-90ed-9428dc214828	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:19:33.196627+00
bab790fc-f9bd-411b-a656-5d638d005549	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:20:05.089117+00
be4ee164-24d5-44df-be8d-36825642fdcb	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:20:32.478345+00
1a969d51-ac87-458d-9db9-f7ae5d923c1f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:21:04.329251+00
d426a980-0723-4eb0-a5c2-d509c138384d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:21:33.14248+00
844af6fa-fdbf-4cd0-a0af-53b983a08fe3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:22:04.104961+00
43a22c71-7562-4f00-945c-3f9a5c3d99cb	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:22:32.272442+00
0914fe51-220c-49a6-85f1-3192b47f1502	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:23:04.285648+00
db41cf06-7b59-463c-9fed-a5aa2b37f0db	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:23:33.134536+00
0d5b8eb0-1c30-4a3a-a948-e1a8bdc675f8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:24:04.419487+00
3cb4a4bd-cbe5-4578-b8e0-ac33bd6e0a33	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:24:33.395283+00
26feee7b-6739-4192-8097-19ed2c30a253	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:25:04.435101+00
e8a5acf2-e4cc-409c-beda-bc7868c7c670	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:25:33.581241+00
42c7aea0-4d6f-4a0a-a3f4-138e5381fd76	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:26:05.090549+00
4787ffa5-952f-4fce-a0e7-cfb9a063e22b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:26:33.576064+00
19797328-2ce7-4f6a-9666-99d6ed3bb671	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:27:05.329987+00
d75245ff-b8d3-4f59-8e7d-129f803016fc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:27:32.168525+00
bdf69b06-4207-4f57-94ef-7b43c65ec04c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:28:04.184392+00
746f7fdf-6046-4e48-a94d-6d809fb59bc9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:28:32.33273+00
01f79efa-8092-41d9-803a-dba249a2402b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:29:05.14911+00
65cc4153-f45f-4f67-9c19-c9bfd9e80f04	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:29:32.637577+00
3e8d759f-6816-42cf-81c6-a9ac138aaff7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:30:05.177859+00
dd08570c-5894-4341-bdcc-5f3ee051c011	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:30:33.605236+00
02bb930f-2113-434b-8c1a-1586f6ad613a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:31:05.218175+00
dd787ba4-7215-4cfd-99f1-54c42f2b7f7a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:31:32.535476+00
ad67e2d7-3e57-4a00-95e5-4fce11e02c2a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:32:05.26244+00
bcae3e38-eca0-40e9-beee-f497d903ae70	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:32:32.596574+00
f4640dc1-cdf7-478f-bd52-cdbd7fa27b52	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:33:04.305859+00
7bb6ea84-4636-4bb8-bb6f-2570f485dd84	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:33:32.399985+00
cfe437c1-2194-494f-ba1d-57e5c483b877	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:34:05.368701+00
da19c6fa-bdd7-4154-89cc-b7a5010eef3e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:34:32.666423+00
9f80ce28-d0cd-42a9-83e0-5b1a68c4fd55	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:35:04.291387+00
adb97bf4-88a6-4ecc-86e4-344333955602	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:35:33.160883+00
2964a93e-eac4-46b8-8f6d-d44d10a7591f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:36:04.378602+00
f3ba5775-0c13-4e09-a2e6-43d17146c9a7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:36:33.578607+00
46dbb180-5455-4114-b6bb-6399d203bbd1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:37:04.618524+00
7875c256-c810-4607-b4be-e8166e39e298	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:37:32.851458+00
f41bde8a-485e-4205-b442-dc55b93644f4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:38:04.165454+00
b3122e0d-7b07-47e7-8ad0-62a7c8db2a9b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:38:32.609365+00
c7d14213-c1ec-45d4-a7ae-b6be6ac0de7c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:39:04.572588+00
063943d5-68d8-4a8f-b776-0e5f94c98992	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:39:33.555446+00
8255e1de-57e3-433e-9e99-9d1e621cc0bc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:40:04.480471+00
69ecb78e-cab2-4242-8959-6713d8912eab	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:40:32.404093+00
0074a4d3-9df3-4ce2-8d27-2d18c356e656	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:41:04.350564+00
9a96d7bb-39c0-48d3-aa86-1fd23e032fdf	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:41:32.316244+00
eae914dd-8e83-4acd-a9b0-2a5ce7a7653e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:42:04.778249+00
6c28d313-dab8-4010-9bde-05cef315b933	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:42:32.774355+00
6be8b8b1-e017-4fac-9f33-89c88a63ba84	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:43:05.532986+00
46e7454c-9da5-4a33-8c50-01a1b14bb722	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:43:33.382849+00
1b83fb45-874b-4be2-bedd-88e374379a16	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:44:04.647043+00
8992c59b-977c-4197-a605-a4ada0747474	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:44:32.974611+00
6fccd7be-ecce-4772-b588-8c440e615ff5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:45:05.549196+00
d3c669c6-e318-4a8d-a24d-449fa1d94377	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:45:33.160857+00
6b4ed76e-87ee-4327-8af0-dbde6c725eb3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:46:05.782414+00
25e32fcd-2d29-4f6a-9d8e-35a017114f3e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:46:34.043607+00
44e3b0ee-5104-40e3-9846-9f866c7140be	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:47:05.66718+00
fdb71886-873b-4439-8407-b2b248b15474	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:47:32.696337+00
4927f911-0c20-444e-a214-74607e319a60	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:48:04.827236+00
c3e02bcd-8c70-4804-8f95-9b3bc2d08fe0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:48:34.371375+00
26db397d-7174-4fe9-9a09-0620d6111e71	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:49:05.393009+00
c7111ab3-ca91-4b5c-afab-3b1052681544	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:49:33.623353+00
e03ca770-b003-49d8-97e5-4c77b7f8846b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:50:05.707372+00
262713e8-1741-43ae-aa44-e02770cac563	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:50:32.717482+00
347f47eb-4930-4fa2-b2e5-4d50b07dff9b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:51:04.775576+00
5b23595f-a335-4864-bb7b-adda78f43a92	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:51:32.823099+00
26913308-ddb6-496b-9062-824e3a4e2c30	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:52:05.027292+00
1523129c-71ac-4c54-b335-ffced35dd5f5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:52:34.754474+00
f0a75c6e-683e-4974-9cc5-6672bd47d298	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:53:05.049478+00
f715fbcc-1715-464a-9491-e51ff9af37cc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:53:31.853835+00
a9d6fa67-7eb8-412b-9e42-e0a903446c5a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:54:03.68872+00
e827f62d-ef0f-4332-9661-e72df06916a6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:54:31.633554+00
758733a1-3e18-45b0-92c9-0d3fdb4e8549	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:55:03.613829+00
7df7c4cd-1810-4c05-80d5-7bb168d24d60	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:55:31.960673+00
f851bca9-e875-45d9-9dca-283eb95de3fd	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:56:03.84012+00
0caa9ead-1e44-456d-9e4a-69f7ab1e04b8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:56:31.783896+00
825cd541-c2f9-497d-800d-323e3fd8d68d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:57:03.821478+00
3d22b905-9724-4e1c-81dc-d5f44953e512	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:57:31.601459+00
c186d2bb-afec-4af0-aa44-5b75ccb3dc15	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:58:03.844569+00
082281fd-8eff-44bf-a26c-36ea559aa8ad	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:58:31.999076+00
1c9d36b2-f9d6-4497-be6a-7371cafd7c4d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:59:04.96557+00
9faffa69-8403-4e17-98da-e525e2aede3d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 08:59:32.1274+00
119b9e56-7735-40a5-b4b1-098318d9582b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:00:03.760475+00
769466cb-ecd4-47e3-9928-a0c5d96414a7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:00:33.160863+00
528fe758-0b0f-45a7-878a-f1ea7fc91ce6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:01:05.154826+00
095b3dd4-90d0-449b-8632-8a5352333e89	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:01:33.098072+00
6f129d2f-a74d-4144-8484-54fd4d01cffa	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:02:04.270622+00
390676fd-57b5-41fc-98c7-9e779c757db8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:02:33.465517+00
ca22fac8-3ff2-4b70-bad5-2e5eaa03d7a7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:03:05.106045+00
d4c0d538-4e9d-4b6f-b8f5-0b253e860623	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:03:32.475442+00
e1a922dc-75e0-4784-ad4d-0de4598cdd4a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:04:04.956636+00
c258e5a9-e50b-47ae-9e36-9d616193a7c1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:04:32.68485+00
8ef27537-0315-436a-b795-e21353bf0c3e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:05:05.257509+00
3f18d238-41f4-41b8-8def-ba7607dc8378	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:05:33.171813+00
5e68742f-ba73-48ce-b15b-a5fe299713fa	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:06:04.015054+00
662aa554-2796-4def-ad3f-980b05d0eb0d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:06:32.273273+00
7dc0b421-b069-4f47-9315-cb9a836967db	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:07:05.173016+00
900fe661-b553-45b5-8488-22df8bf2a352	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:07:32.513164+00
10d38d61-ac4a-4b22-a677-2809a9f95766	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:08:05.295134+00
d534c5cd-31b6-4618-814e-1bdcea5fc9b9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:08:34.065191+00
76b3962b-c256-4506-9d5e-33b137c9cb0f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:09:05.555026+00
95a2626b-63d6-4f69-a676-5c91e815c2ff	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:09:32.514223+00
6c90a656-c164-4f78-934d-4b7a995e578a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:10:05.335517+00
71a77c04-f1ff-4ac3-892e-c3b18be105e6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:10:32.538102+00
cd613ca9-9b53-450f-bfb4-c528e1e8f1c8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:11:05.349507+00
73e2e77c-9e4a-4be3-afc7-709b9d18c302	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:11:33.22518+00
95ca095a-7bf4-4eb4-ad2e-d057e2a93bf9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:12:04.590421+00
f43bfd8d-3fae-471e-a75a-718bb164333f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:12:32.418244+00
564cc937-2525-4778-8226-edfdec5d671a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:13:04.506502+00
78b11d3f-686b-4c75-91e0-2c62ac020d66	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:13:32.234985+00
84aad596-4a93-4784-919b-db7653d7d387	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:14:05.106954+00
4b961e4e-19e7-46a4-bc08-71ee8af466ff	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:14:33.417109+00
124a5128-e1f0-4415-8aa3-06a0515cc056	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:15:05.377869+00
8c633958-3ece-4b1f-9636-a35c9c115514	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:15:33.47464+00
1164992b-3e8d-407b-9a2b-ab3aff48c27a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:16:04.375695+00
a3833c21-fb4b-4439-a915-67a22e33bcd0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:16:33.632597+00
e8e7e452-82fb-4be4-923b-19b1d9b0df73	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:17:04.48683+00
d59334e1-8c82-4a7b-970c-97493ae07c98	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:17:32.673069+00
eec0b6d5-2c9b-44e5-9c6d-7b7b0dd84ccb	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:18:04.779684+00
27d17168-7ea1-4ba0-94fd-d6db8c425dfb	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:18:33.517351+00
dde955ea-f881-4b14-834e-9643b9d877f5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:19:04.610582+00
ba00fd7e-c3cb-4b16-897f-29a05211e57f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:19:33.487132+00
0e580b3c-ad7c-41a9-8247-c6e424339b8a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:20:04.567491+00
326afe7e-57cf-4c58-ba2f-fce3429b5b80	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:20:32.722835+00
1027dd79-4452-4692-8323-62f62f226676	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:21:04.727437+00
08d2bb85-0e68-4a56-9d57-001833176c27	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:21:33.710456+00
b001e5b2-39e8-4afa-9048-bd7c05d8f55b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:22:05.657072+00
526837df-dc46-4dde-9556-88015f28b3c5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:22:32.816972+00
976c23cd-32c0-4734-a285-c57be321ba8b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:23:04.825362+00
cf5011d7-4702-4675-87f0-2ce4ebf80f2a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:23:33.001587+00
9d0456a6-72e7-4833-8c3d-b2f5c464f5a4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:24:05.433086+00
7004e88f-d1c0-4b96-b303-7945bf8abad2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:24:33.888394+00
60904a1d-9c9d-4850-9373-7b454063abbc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:25:04.92848+00
f5dc8328-3498-45a2-a601-f85a41269e87	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:25:32.026522+00
9cc7159e-d0d7-4fc5-8900-abc33d4e6975	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:26:04.866496+00
0381117b-455d-4ee6-b361-5be14a53a1d4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:26:32.322564+00
5767f0c7-8cc0-43a3-9da4-6260a7d74c9d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:27:04.206429+00
3720ad47-0980-460e-900b-b05835dcecd6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:27:31.692335+00
d0265895-1d05-4068-baa7-34d8026a8c9a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:28:03.419061+00
a559136c-80dc-4130-9bb1-cd256b19222f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:28:31.759854+00
cbe987e1-7a27-499b-b925-770ffceb5c0f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:29:03.431745+00
d299308e-e315-4f72-a004-036bb9ffdeb7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:29:31.701996+00
4b004c7f-9b9d-4efc-91ea-a6e5db872e6b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:30:03.843302+00
be94c87a-53f8-40cd-a7b7-8c34c2638389	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:30:31.759485+00
afab71e0-1bd8-418c-8946-44011fc72a16	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:31:03.858128+00
3e38b787-15a2-4199-ac20-6d5b42ac5680	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:31:31.695416+00
abecf977-9aba-4d6b-81a7-f604c68618a0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:32:04.899564+00
51a80a6f-fe11-4a2e-9813-dcc2b387ace4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:32:32.194318+00
51e94d5a-c4fd-4042-a012-2d9f1f9a93ff	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:33:04.999053+00
5cc97ff1-2845-413d-855a-064ae31bcb0c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:33:33.416667+00
57bdc46a-96cd-4134-bed3-eac5474711f7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:34:05.074785+00
9adbfc75-251d-44c5-8226-159a2891d9cd	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:34:33.486287+00
fbaac04c-8243-4c60-9888-d745068ebabc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:35:04.245505+00
14d403a8-210f-43f6-809d-c99d146deac6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:35:33.058152+00
98061b2a-7087-4958-9f09-4cdfd8710bb7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:36:04.329598+00
4e0c62fb-78be-4bb7-b55c-1dd88885260c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:36:33.68641+00
8b3f235f-f562-4ed1-91ec-33d53ed8bf21	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:37:05.495472+00
c057407a-b751-4fa7-862b-6ecd7765bbdf	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:37:32.354532+00
49d97ed0-0209-40c8-9b91-782922c44928	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:38:04.493993+00
59523c59-3208-4c4d-888e-026ae8247d8b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:38:32.325317+00
bd776527-41b4-466a-8316-86b3f8fb126e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:39:05.087713+00
f1e890bb-498c-400e-86ae-57b2d205a071	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:39:33.546812+00
5c497da9-224d-4859-b25d-89c36cdb82b4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:40:04.147903+00
bcec1540-eb55-4240-8aa1-af0b7fe9cd11	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:40:33.016658+00
60219b46-bb4e-469e-bfbe-136cd2ddcf19	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:41:04.955395+00
076067d4-d9d6-4ba6-ad6e-f4a8c92b96c2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:41:33.127413+00
1f1be0bf-2e21-41bf-b0c4-0b360abfb562	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:42:05.395459+00
981de7fe-9dff-4390-bee7-aead41030a89	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:42:32.374615+00
d6e7dc08-a603-46e0-b5fc-5cb3057b54c1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:43:05.271307+00
ad86553b-7266-4eaf-a134-d9e671d531d7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:43:33.297872+00
fb4635f3-bffc-4b60-8406-e25304caaf5e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:44:04.79209+00
5e68d6b7-2fca-43ef-b6a4-0ead2264712a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:44:33.298638+00
72ae6a8e-6249-4a9d-ad15-4ea5d7a564d4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:45:05.199626+00
92e84997-081c-498b-9b29-456646a9dcd4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:45:32.395095+00
4ef33bcc-a47c-4700-9976-4b12e56c2a90	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:46:04.668407+00
7c94880e-9641-44df-b234-f3f0be684ccc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:46:32.779549+00
1e1876ae-f03b-4991-a54a-9aa82355e2bf	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:47:05.01768+00
c5cbcb15-3ac8-4476-8aa6-fd1f2e706735	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:47:32.853006+00
613f5d04-a65f-4859-871c-a7bc7b9d7d0d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:48:05.699354+00
0d33b3ab-043c-42cc-b547-6bad9e894ff8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:48:32.777469+00
d18ae842-7f31-47e8-9e23-7ad0f60cb023	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:49:05.375041+00
118d7fc3-14e7-420d-86b8-ef5f5c3430ed	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:49:33.469031+00
77a3db08-9b98-46a2-bb09-7078238df025	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:50:05.458551+00
017c4000-5e2c-44c5-bad0-1e0f77e49e24	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:50:32.915292+00
66dbda52-751f-4ac5-bc95-504c52fcf620	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:51:04.745129+00
3c6d22bb-2ef1-4211-bc54-4ae4ad3f7bce	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:51:32.839308+00
91f4bca5-42c6-47db-905d-1e48a3031083	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:52:05.447623+00
9fe6c444-f06a-4bc0-83f6-38197c0c46b8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:52:32.716856+00
eb6e2bda-18f0-494e-91be-6001b7a67364	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:53:04.78591+00
f696f47e-5f3c-47af-8983-dc3b80d57e73	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:53:32.690722+00
007e4a5a-7d7d-49e0-817a-a6c3e03ae447	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:54:05.646911+00
dc102645-0bb2-40ce-a023-8bb6631943a5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:54:33.694384+00
f9685616-dd6b-4b5f-bd39-b18440520215	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:55:05.256243+00
9ba07135-5d56-4302-a83c-2578eb237d7e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:55:32.647128+00
12604f1a-5742-4e6f-a788-b418f65cf6a1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:56:05.642072+00
56825ce1-cdaf-4845-8b84-458b42d2e0a7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:56:32.846189+00
3b6024e5-e221-49cc-b0a7-bc5d178860bd	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:57:05.574445+00
fbd46a88-5109-413e-8166-dd4ce2571198	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:57:32.576284+00
aa37ce5a-7caf-41c4-a26a-479b1896ef8a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:58:04.590434+00
4d6fc6eb-fc2a-4833-8ac1-3916df3b5850	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:58:32.96755+00
1e79afed-42ca-453f-a715-e357b347fba6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:59:04.59952+00
90b947eb-1c48-4362-bfb7-8b7ba434a8b5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 09:59:32.697238+00
750f5b5b-0b8c-45b3-8343-27fcc7b9684c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:00:04.967558+00
789e2540-7c7e-49a4-8d65-4cff3f841817	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:00:32.683063+00
39a7af3e-ceb8-4618-b5c9-0673798fd935	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:01:05.463152+00
664db31b-9fef-4e14-acb6-e04e288b9409	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:01:32.896304+00
0c81fc15-1dc8-4210-a253-9c9f7b08b2a7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:02:05.852955+00
2ee4fac8-bdd7-4e45-8dbe-feb43b0365d3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:02:33.396488+00
1108c8f8-59bf-449a-b020-43cd7a6b11da	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:03:04.751188+00
8829f474-22de-4279-8ac3-a49f2072b35c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:03:32.784191+00
40ea2418-19fe-48c8-8f06-40b6a13c0d6e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:04:04.839124+00
562c7cf7-e829-48a1-9e7c-f46753cb07f9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:04:32.740981+00
7aca7d3c-df08-4fa5-b259-9305ddde0e1e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:05:04.717797+00
937306a0-c1d2-4199-b88e-376cd9907f6e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:05:31.709698+00
fe4a446d-753d-4eb4-8558-714b2de1210c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:06:04.038934+00
2feee01b-c551-451a-878d-b66e8bfac006	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:06:31.834571+00
5a48a522-3267-4a30-bbfd-2768fcdb0f37	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:07:03.615255+00
25bce64f-26bb-4291-ae71-6e67c7aed336	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:07:31.691259+00
7db47ed5-9e04-471e-8a24-815829a3bf59	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:08:04.505399+00
8f3f1768-3b6a-4818-98a0-27417b242d20	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:08:32.776262+00
1db2ddd1-5754-470c-85cf-7bbc62e40d84	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:09:03.655601+00
87b71a83-d0ca-4667-9f14-8b5429655774	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:09:31.95704+00
c47434e4-2ce1-499b-8a69-22bc55761b9b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:10:03.710445+00
c2fb9cf4-8eb9-4f71-9a2c-3526fdcf6d3d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:10:32.219614+00
3a7b1737-15ea-4636-afa4-5119304b0223	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:11:04.708333+00
203043b4-f8da-48e6-b6df-3c3be38f7819	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:11:31.718181+00
cca4a734-52f6-4259-bb8b-608d1f5d1d45	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:12:03.744746+00
d11bf32a-f189-466b-a61d-d2e973ac94e0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:12:32.233086+00
c1978204-bbf3-4321-a788-29daa7bbc82c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:13:03.781827+00
597b714e-d642-4e07-9eea-42c7ddba825d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:13:31.911954+00
08cc32ff-527f-4db1-a830-0fdb36338291	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:14:03.873379+00
10c90f01-c913-4ed7-bc9b-96c6e9fc42b0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:14:33.066977+00
5a56208c-9992-4f3c-b26f-cf5ee405ce3d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:15:05.017259+00
33c28b9b-5b0c-4e34-899f-efe892ad32e6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:15:32.464137+00
0a25344b-f8a8-435c-9efa-ad57d2a2be3a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:16:05.115189+00
24a8e4ea-5cea-4bc9-a000-e888713dec7e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:16:32.14414+00
523e64b1-793b-4bb2-84bb-b234531fca1c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:17:03.939258+00
2670a443-02e7-4a96-978d-7c29885f0684	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:17:32.041195+00
a2479c4e-ba3f-4c3f-bd7d-e6fd0db0784d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:18:04.113298+00
4bcb4cea-a9ab-475a-8cd4-7297156bcb76	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:18:33.108644+00
2f4ecdc2-6cf7-4e33-bb49-f45cc540dc79	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:19:04.242649+00
80cb4da7-259d-4d66-9a8b-66bca82ee4da	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:19:32.310859+00
a92b9e53-8468-4667-9b2c-82326110ccc0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:20:05.69301+00
31103708-26dd-474b-99bd-74639afdcbb0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:20:32.438923+00
4486c9f7-5d05-4f83-be19-dcca63e09203	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:21:05.365527+00
e3c354da-51bf-45b4-a9cd-607ec05339d0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:21:32.609387+00
7da0c2bf-e1ab-474a-bd78-67161c27c15a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:22:05.263619+00
3483b46f-f172-4d9e-afee-74fa449ea9ca	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:22:32.269144+00
3400a086-74cf-47cf-a6f7-149909f5edb5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:23:05.099118+00
9936743e-932b-47c0-9c1f-a3595dd855dc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:23:33.234957+00
ae85c3f9-694d-4ca0-9cdf-9f3998ce24a7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:24:05.335253+00
a9e44dc1-70fe-427f-8f12-5dfe35aba8d3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:24:32.491262+00
bb4e69ca-247c-4698-b23e-9b1c0f414ca9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:25:04.152992+00
061f14bd-8e38-4592-b621-e9e3b8a3e0a0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:25:32.77058+00
76e43980-91aa-4395-beb5-32724373388f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:26:05.450439+00
bf6e3135-8092-4846-b8de-b795e2df8db1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:26:32.601797+00
2c385776-291a-479b-9b97-bc364dc76405	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:27:05.345033+00
8dc5a61e-9950-4053-9b9d-e56330f37b7e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:27:32.746474+00
8799cf37-6a57-44f7-8c42-75c4cde2c39a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:28:05.481614+00
eea2a08b-1c93-44ed-adf5-38836e9d0343	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:28:32.73652+00
46c1ce68-7215-4b94-bab9-3c9026937a29	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:29:05.378754+00
050ef101-32ad-4d24-83c4-e1bbdcb8654b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:29:33.58448+00
d2ec121a-c316-4638-b206-a69054232631	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:30:04.618144+00
dc47a7d1-e1e5-4eac-98c6-a7d8b07fc4b0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:30:33.52497+00
03a7e291-f53d-4f00-bacb-8718e3bea1df	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:31:04.305181+00
26d43176-e3ea-4dde-a83c-6f1c588f3d4b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:31:32.994045+00
67909844-d836-415a-b72e-fd0866226a38	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:32:05.416227+00
eefbdce8-c323-4cc3-b21c-445499482999	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:32:32.631719+00
6742fb06-5e26-4941-8b44-1a637a4e92af	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:33:05.722143+00
b0812b17-972e-491b-99be-89bc2c7b1dc3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:33:32.679615+00
369afb2b-ca5c-4fe4-972d-6b4fa072a896	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:34:04.334497+00
49520d8c-8f1e-4e16-8726-bf9743756577	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:34:33.753752+00
32b0dc8c-eb82-46a5-a676-f3a1a01bfa44	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:35:06.368353+00
ce333d7c-9d60-40cf-b02a-7cdbce2b7825	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:35:32.928973+00
cb21b206-9a33-4775-ad44-cdf15115977e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:36:04.560546+00
8bf84992-3d74-404a-9a2f-4147d70e7873	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:36:32.911506+00
88b9a7a3-c634-4c1a-a83e-d6760a484431	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:37:04.776602+00
9a0ccb7e-d0c5-4f94-ae44-296d95b7e6be	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:37:32.746947+00
d48e7f25-ef06-4b73-8d37-f2c8f5f9b50c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:38:04.808505+00
d730ed18-c443-4986-95a1-721d6ad75156	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:38:33.055278+00
b035b71f-1c9c-44ca-84d9-c7b227f7fde7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:39:04.009849+00
fdb82749-1c95-4813-be24-08277845550d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:39:32.720606+00
2dd86a1e-665e-4c84-aa39-9f2226d41f61	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:40:04.723032+00
be1f6e23-a969-45fc-9496-3309d722441d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:40:31.966767+00
aacf1d41-9a35-43fd-9f70-101719298c9b	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:41:05.106334+00
c322d58e-c2eb-4778-a310-acd978f5a184	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:41:32.462491+00
a3996fd0-747c-4b8c-8ad0-ee61a1f43eb2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:42:05.652982+00
63950c97-50f8-4192-a210-8506e2d6db37	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:42:33.647024+00
10083602-32c5-48c5-8105-ea6c5bae8c7d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:43:05.281128+00
3ce813ed-1ec0-425e-8d3f-1ba0ed7326f2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:43:33.626396+00
94157d65-f8ca-4353-a98d-67264f65e4b5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:44:04.921835+00
ffd9b253-b7ad-48e4-8934-b022a14b9196	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:44:33.884528+00
4069bf4b-0ba5-4fcf-8fcc-a5181e71a4e7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:45:18.484524+00
2f69e5d6-46a0-46ed-86d4-e4589e2d0e05	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:46:08.688604+00
fd4c21aa-ce75-4ef1-835f-0a56f93d0f55	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:46:42.183187+00
8c79a88d-5477-4de6-8fe0-a763266fbbb0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:47:13.999017+00
df7872f7-1b64-4710-8e6e-5d9c92e283ba	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:47:53.302537+00
a6ea1e07-a9e7-49a0-9d9f-551c0423f12d	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:48:19.328118+00
11c2dc74-c1cf-4bab-b39a-b3d33ebbdd3c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:48:48.286378+00
43410fcd-c85d-4592-b22c-329efd1c7bfa	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:49:20.065483+00
e9a194ef-43eb-4dbc-aaac-e8552993ed21	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:49:47.946514+00
4b905d0f-8e0c-4a89-abe9-278dc2a8bd4e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:50:20.206014+00
694d0ebc-1e46-4c6f-841f-9ec6f3869859	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:50:48.30459+00
1009f1ae-0391-4b41-a7a2-5bf994d0a0a0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:51:19.061746+00
a7e3986b-6fb2-4383-b08c-f752001a2cf2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:51:47.584434+00
ab5b1d70-660a-43ec-a885-dadda287f278	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:52:20.547234+00
68c00eda-1130-4498-9c33-7b9615523f34	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:52:48.972479+00
7c5a02f8-06e0-4f88-b0f7-121c3917cb00	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:53:21.092524+00
8b21091b-6e20-46a9-9f04-fc4a281b055f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:53:48.402479+00
29cd2c05-7aff-4418-b136-268ba0ed8aaf	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:54:22.96604+00
7aeddbb6-a9c2-437b-8672-0582806c8f05	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:54:49.293072+00
9bb544e2-9aec-4cc2-b0e4-2613abe96972	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:55:20.482551+00
5b31c80b-7701-4ae1-87d4-846c6b094df8	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:55:48.722002+00
2db68c02-7cff-4af9-9821-247f77e73be5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:56:21.884489+00
e1504c9c-65ba-42e5-8a6c-becfc773adba	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:56:49.450894+00
70fa24f7-87ed-466c-b179-fb36f4ccc0b4	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:57:21.205504+00
80289dd2-5558-4891-aa70-fa7be2e081f2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:57:49.906111+00
90621b2e-cd00-40c2-b1a2-e03e177accf0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:58:21.516155+00
fe95237b-e9ee-413e-8113-a668b33d0c68	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:58:49.487398+00
ceaeaae0-f6ca-4f06-9538-c21080fe66c0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:59:22.430418+00
bb0725b7-de16-49d9-82db-8e43d4aa09b5	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 10:59:49.742362+00
ce0573aa-5234-4f26-b268-510263d50cac	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:00:22.184852+00
f5f8438e-bce3-4e8e-a43b-454938414488	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:00:49.322409+00
aa5ff536-00f6-4c5e-80e6-7b849028d765	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:01:21.470529+00
6519cafa-3d7b-45b8-b048-566d9966ec20	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:01:49.281931+00
5005739f-790c-488b-b7fb-4ce7c6998ad0	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:02:21.862299+00
6757834c-ff46-450c-aa03-1c5dcceb8fb3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:02:50.042345+00
3cd61c3f-d819-40a3-bea1-f7d3330e0270	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:03:22.422014+00
b146353e-1605-4e23-b5f4-23ea23f1c8c2	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:03:49.912483+00
f0dd2003-1869-4d70-aef3-f8d8b3b69a5c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:04:22.769157+00
1c986116-70e8-4e24-86af-36d0abc7ddf6	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:04:48.49126+00
772ba102-b067-48a2-a067-fbe594cd522a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:05:21.824378+00
456b3a6f-c03a-4819-a44c-4e0a5e68350e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:05:48.741848+00
c23c3e05-f2f6-4c43-bfb4-7748d1183ea9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:06:21.802391+00
f7d3f9c1-28f8-4f49-ac26-ca288efd90b7	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:06:48.870181+00
36b34990-0896-4ddc-bfe6-2f85a1d3d8bc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:07:21.930313+00
3deaa275-5751-456a-a098-6a0ccac21345	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:07:49.33312+00
4c40b825-b10d-41ed-8dce-51adbb0edf18	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:08:21.632534+00
7d3d3cef-ee2f-49b3-b5e7-a26d79765664	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:08:49.961284+00
d230bdee-f16e-4985-9520-100e7b6f6649	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:09:21.246043+00
79340d29-93f4-4629-988c-9055c007a7c9	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:09:48.97156+00
1214883c-b172-41a4-9d03-b478c9b8486a	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:10:20.954789+00
84603534-4f12-4b8f-9e2f-8962fbe63014	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:11:03.677419+00
00b7bf2f-8995-4d94-940f-387189eac8c1	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:11:42.96611+00
c97ffd1b-df67-497d-bf69-e3ec6c54b399	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:12:17.472829+00
b3c6e086-3b43-403e-975c-f44ce7ca8f4c	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:12:48.33779+00
2b6791e2-b4e0-451c-ae38-7aab276edbba	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:13:19.410671+00
bc1a9feb-d235-4dd4-864b-d58911981bf3	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:14:23.53078+00
156e3368-dbbd-4978-9041-a71b2062e206	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-08-01 11:15:20.167626+00
7f597d8f-e1c1-463f-8158-65912841668e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	isp_link_up	ISP link RESTORED — outage lasted 1m	2026-08-01 11:17:04.257741+00
9b87bcd0-cfdb-49c2-a389-5365f78dfc1e	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:17:30.759692+00
09425d17-0cac-4372-accf-2d4548b38670	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:18:13.914577+00
10de1586-289e-4899-99a1-c74f667792fc	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:18:42.32129+00
25e3c2fa-04ee-4052-8536-d5c2499ef227	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:19:16.454111+00
1cc35e93-7c3b-49b3-8f1a-e2da2dc43c08	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	15c14766-aa02-4e61-be85-41b79c3ffe85	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-08-01 11:19:58.017994+00
\.


--
-- Data for Name: nas_wan_links; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_wan_links (id, nas_id, "position", name, interface, gateway, ping_target, role, lb_weight, enabled, current_status, created_at, resolved_ip, resolved_gateway, last_checked_at, last_rtt, is_active, internet_ok, in_load_balance, is_failover, failover_priority, last_latency_ms, last_jitter_ms, last_loss_pct, quality_state, consec_degraded, consec_good, quality_parked, probe_verdict, probe_stage, dns_ms, connect_ms, fetch_ms, throughput_kbps, last_fetch_at, consec_fetch_fail, sample_history, consec_slow, bytes_carried, bytes_since, last_tx_bytes, last_rx_bytes, bytes_month_start, in_pool, last_mbps, tp_checked_at) FROM stdin;
f8f4c8e2-ae51-496d-82f1-db870d12e69f	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	2	Link 2	ether1	\N	8.8.8.8	failover_backup	50	t	standby	2026-08-01 06:13:04.368487+00	192.168.8.6/24	192.168.8.1	2026-08-01 11:19:57.000044+00	28ms367us	f	t	f	t	2	\N	\N	\N	good	0	0	f	good	complete	\N	\N	2193	\N	2026-08-01 11:19:56.712275+00	0		0	577437538	2026-08-01 06:13:04.368487+00	90328364	513546844	\N	t	\N	\N
1f3bd270-08f2-429f-970f-31b0e6914e90	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	1	Link 1	ether2	\N	8.8.8.8	failover_primary	50	t	online	2026-08-01 06:13:04.366731+00	172.31.4.134/32	rl-wan-pppoe	2026-08-01 11:19:56.998307+00	7ms609us	t	t	f	t	1	8.245	0.3	0	good	0	577	f	good	complete	\N	\N	1199	\N	2026-08-01 11:20:15.50347+00	0	0000000000	0	623865664	2026-08-01 06:13:04.366731+00	345780232	663812211	\N	t	\N	2026-08-01 11:10:59.68082+00
\.


--
-- Data for Name: nas_wan_policies; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_wan_policies (id, nas_id, priority, name, match_type, match_value, action_type, target_link_id, target_link_ids, enabled, created_at) FROM stdin;
\.


--
-- Data for Name: nasreload; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nasreload (nasipaddress, reloadtime) FROM stdin;
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.notifications (id, isp_id, admin_id, type, title, message, is_read, link, created_at) FROM stdin;
3f6e2030-2721-466e-972b-ac077c2dfe79	\N	\N	info	New ISP Registered	bonte has registered on the platform (both plan)	f	\N	2026-07-31 18:23:20.042518+00
1dbcb3b0-400b-4151-b50c-8187bf2c6135	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	success	MikroTik Connected	"DandoraP3" checked in. Run the import command to apply config.	f	/isp/dashboard.html	2026-07-31 18:26:49.478569+00
2176396a-63ca-404d-a881-4c68c4f931f8	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	success	MikroTik Configured	"DandoraP3" pulled and imported its config.	f	/isp/dashboard.html	2026-07-31 18:27:06.370535+00
7f7d9f41-1096-4479-bc54-e2741bd01655	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 18:42:00.136263+00
e80ab463-a84c-4161-8d81-79b87ba67dc7	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 19:09:00.809387+00
be60f80d-9df2-4181-8384-1c8c748283a9	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 04:24:00.626901+00
3c245831-c928-4e5f-b355-9fcdc2d4c40d	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 06:06:00.244546+00
5e0a5c27-a8a6-403e-9085-5c10a3109da1	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 06:20:00.686127+00
552a2210-f130-4f85-a7c3-d0101dfdd2d4	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 06:43:00.38384+00
9f7a006d-bdd8-41fa-ad1b-db2b3fb99bf0	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	warning	Invoice Generated	Your monthly invoice of KES 741.75 for 23 PPPoE users is ready.	f	/isp/dashboard.html#billing	2026-08-01 08:00:00.715001+00
\.


--
-- Data for Name: payment_provider_configs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.payment_provider_configs (id, provider, label, merchant_code, consumer_key, consumer_secret, api_key, private_key, public_key, base_url, is_sandbox, is_active, created_at, updated_at) FROM stdin;
a4c097d0-d422-422a-b556-db68de15d422	jenga	\N	1587205221	\N	9qFZ7w5zKti9nXVlK8Zl28Cr3Z14oD	7bg07O+pMst83rwQavCCtLKQiA693tOKJeNS3VMzRRG0CI1FtNbdC4U9ULNu2V0ePAU/P1V1oOBrbCeyUsv2Og==	-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDZgGWIQcLQArlq\nVzrF4SV3KoA9QMChkSzbwruSL5k08wICvVyeJDGWQrhuViMmD8zts7Pi4crINnj/\n1A3Xu1j50CrLUl8g0LkutaUJmlBFLromrWItuzG44fNJcAfa6+NS3bsFXONFz9Lw\npPraasG+01XH5SlOC9eO+1sArs3Yt+s/GiDlYvbX28ALMjfX6tUV1vzSjBsvacRS\ndLCXCGZrM/K5pYKjyd3UgigRUsnWmgzNVsV3buXZqh936UcHvT48YHo0TuqYsq7d\nsV0OchtliY4P29eKHLt4gpP5b1TyWl4Mt9inQOwT8UrU6AHrEiECBRTfkQXS5JPi\nT2BSmzL/AgMBAAECggEAEdBpQHlsxjjnswG1YusRJ8sq2Rl6TYfEiue03jQya63l\nm1zWftTyQywJ/m6x27AanEA5YQ4WQkMeTCUA0NhCFHMYz8tacEEekbVRJAUbQvdU\nFs8UbGNzHwEeoIRIMgWOk/hslQ1dFGUBRWV11R+ktVQkDmApSGbbsmHJVWtImWtp\nD7Rf+7XE6Zel+IbAFnHhICnaUOxoSWE3nNmOhYyRBniL+2r4v7LgRonZLWrcfAJ6\nxz9kLzvKcFS4xRMY1aEcfV+g5yu8rVWJlp4ImsL/qFJXfezhW5lN6lI2DxUv/3DQ\ntLTDQktPl4nX2MdZb+RTocPN9yIw9ZOlV9QueOtT4QKBgQDsfAA9sgQVNXsC46+s\nUuEpDRRVyj5iSCSBOZnILwMq+I1ZLWbZE4rhyK8XuEjkAApRbu8gxbEwB/1rHLnO\nl/9QIogveDJBOJoXT0N2KiI1EAJJ1byarvqKYpJ9qt4rXKSHHsuXK05K+jtvngh0\n3IZTEqQ15nx4KUNXK+RSyc1EHwKBgQDrc1ysEZK2dIXzUfNduuwrtJpWvPjOEyXL\nedNIe6MShpeo8KAyCtCmFY6yFbkuwIiu+hbqy+zunEZnV5wtCurbDaAKHuys/LG8\npiyoRE2SSMjxhlTcAejV+iacQIicsJMxgZ1CYgJYPiQhzGi4G2apBXaQoFraS/dH\nUNw2lpU1IQKBgEoxSR4SCIfi5HnulwHYar2nVdbogZPyEEnemWmdnj/QBQCSZu75\n25uki5JEhdHKVXJg/HLqswFfsFj3hS/UrgwlGVbTPekKagWgH4kmBN9i62TgwrBA\n72eVL2Jvxg4SnaequLLvqjuJsDX/faW0Pgw4D/69FhXY1EC4C4URvO1/AoGAbpL9\nAKo4FovepIjmHCy+4T+uA/I3fsArTcXm3fGCgh7HdsWa1iWSG42gOC5Pi49MIbC9\ntoMSwHSP89SHOfgYl8tsT5R6XjtGVWxNKLD7JSodhKArli8nY+ZY36THA59BYUyX\nyCczJrH4Ug8nVt83dUVli0JjqIVomgt1gAV0CUECgYEAnbNrjveCgrQO5EjjEJdQ\nIT609vwNH8C1ejhBKjnTUN5+mLeiufDKt86Bn0a0qftpyZVO2DGdgHb10+reZJdM\n7l06KDwHPej5b2XemSITbJSZy2oLeI4qhBa/dc61NhrgtXlFp/zfSFcGVkEduVmu\nTXA8NtHeQFrZ0mdh8TnNX6Y=\n-----END PRIVATE KEY-----	\N	https://uat.finserve.africa	t	t	2026-06-22 09:55:15.524141+00	2026-06-22 10:01:08.802393+00
216d93ea-0023-436c-9f8d-f5050ebd40ec	intasend	IntaSend (Admin)	\N	\N	\N	ISPubKey_test_c15f0971-500a-4094-ade6-bda28e35acea	ISSecretKey_test_6c53c610-5e1f-47fe-b9d1-008d1a2a18e7	\N	https://sandbox.intasend.com/api/v1/	t	t	2026-07-10 12:08:52.135529+00	2026-07-11 15:09:14.748197+00
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.payments (id, isp_id, subscriber_id, voucher_id, amount, currency, payment_method, payment_gateway, transaction_id, gateway_reference, phone_number, commission_amount, commission_rate, net_amount, status, failure_reason, description, metadata, paid_at, created_at, updated_at, used_admin_credentials, forwarded_to, forwarded_at, forward_status, mpesa_phone, mpesa_amount, mpesa_name, clearing_status, cleared_at, intasend_invoice, mpesa_receipt, voucher_activated_at) FROM stdin;
b0a9c88b-d99e-4d52-94e8-8abecf2285f4	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254740258495	0.15	0.0300	5.00	failed	Request failed with status code 400	Hotspot - 1 Hour	\N	\N	2026-07-31 18:37:06.928562+00	2026-07-31 18:37:06.928562+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
a7d91802-3dd9-4ae0-b4d4-90e0cde3231d	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11314QE7	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"mac": "BC:2B:02:3A:7F:7C", "is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "B32", "rl_purchase_sms": "sent"}	2026-08-01 06:42:50.257958+00	2026-08-01 06:42:30.4625+00	2026-08-01 06:42:30.4625+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 06:43:00.373605+00
8dc76f51-bccf-4d51-8369-cca7c8f75e8a	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV1313N78	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-07-31 18:41:41.072407+00	2026-07-31 18:41:26.103351+00	2026-07-31 18:41:26.103351+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 18:42:00.074582+00
e25b8ef9-ddba-4006-9a81-606bbe3a091c	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	\N	5.00	KES	mpesa	mpesa_stk	UH1JK11WU4	\N	254796829688	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "B30", "rl_purchase_sms": "sent"}	2026-08-01 04:23:00.022342+00	2026-08-01 04:22:47.307805+00	2026-08-01 04:22:47.307805+00	f	\N	\N	\N	254796829688	5.00	\N	\N	\N	\N	\N	2026-08-01 04:24:00.592113+00
1f82a039-1d31-4600-8eac-7d1ca0f83fb2	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11314F3A	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_purchase_sms": "sent"}	2026-08-01 06:05:51.786264+00	2026-08-01 06:05:41.028257+00	2026-08-01 06:05:41.028257+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 06:06:00.218648+00
990e2277-2755-4c33-a046-9fa57038ff9a	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV1313SO9	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-07-31 19:08:42.046742+00	2026-07-31 19:08:30.695531+00	2026-07-31 19:08:30.695531+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 19:09:00.787443+00
a6d77fe2-2999-4d0c-9952-c8efb1868c7d	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.15	0.0300	5.00	failed	No response from user.	Hotspot - 1 Hour	\N	\N	2026-08-01 06:17:19.232457+00	2026-08-01 06:17:19.232457+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
210de0e7-ee63-421b-8090-d5ddecfae32c	15c14766-aa02-4e61-be85-41b79c3ffe85	\N	\N	5.00	KES	mpesa	mpesa_stk	UH1C811RP5	\N	254117195942	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "B31", "rl_purchase_sms": "sent"}	2026-08-01 06:19:17.847786+00	2026-08-01 06:18:51.705018+00	2026-08-01 06:18:51.705018+00	f	\N	\N	\N	254117195942	5.00	\N	\N	\N	\N	\N	2026-08-01 06:20:00.665711+00
\.


--
-- Data for Name: platform_secrets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.platform_secrets (key, value, updated_at) FROM stdin;
intasend_webhook_challenge	benrade@d25410282017	2026-07-11 13:24:38.759417+00
\.


--
-- Data for Name: platform_settings; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.platform_settings (key, value, updated_at) FROM stdin;
sms_price_per_sms	0.5000	2026-06-27 07:42:44.358443+00
sms_cost_per_sms	0.3500	2026-06-27 07:42:44.360594+00
sms_signup_bonus	50.0000	2026-06-27 07:42:44.361833+00
hotspot_commission_rate	0.0300	2026-07-03 15:11:49.786236+00
pppoe_per_user_fee	50.0000	2026-07-03 15:11:49.789272+00
intasend_collection_cashapp_pct	0.0450	2026-07-10 12:08:52.082679+00
intasend_payout_mpesa_flat	100.0000	2026-07-10 12:08:52.082679+00
intasend_payout_bank_flat	100.0000	2026-07-10 12:08:52.082679+00
intasend_payout_bank_pct	0.0000	2026-07-10 12:08:52.082679+00
intasend_payout_b2b_flat	100.0000	2026-07-10 12:08:52.082679+00
intasend_max_fee_ratio	0.1000	2026-07-10 12:08:52.082679+00
intasend_method_mpesa_enabled	1.0000	2026-07-10 12:08:52.082679+00
intasend_method_bank_enabled	1.0000	2026-07-10 12:08:52.082679+00
intasend_method_b2b_enabled	1.0000	2026-07-10 12:08:52.082679+00
intasend_collection_mpesa_pct	0.0300	2026-07-15 23:14:55.083241+00
intasend_collection_mpesa_max	400.0000	2026-07-15 23:14:55.085713+00
intasend_collection_card_pct	0.0350	2026-07-15 23:14:55.087134+00
intasend_collection_cardintl_pct	0.0450	2026-07-15 23:14:55.088616+00
intasend_payout_mpesa_pct	0.0150	2026-07-15 23:14:55.089897+00
intasend_payout_mpesa_min	10.0000	2026-07-15 23:14:55.09109+00
intasend_payout_mpesa_max	50.0000	2026-07-15 23:14:55.09224+00
intasend_payout_bank_t1_max	10000.0000	2026-07-15 23:14:55.093375+00
intasend_payout_bank_t1_fee	100.0000	2026-07-15 23:14:55.094592+00
intasend_payout_bank_t2_max	50000.0000	2026-07-15 23:14:55.095744+00
intasend_payout_bank_t2_fee	150.0000	2026-07-15 23:14:55.096974+00
intasend_payout_bank_t3_max	100000.0000	2026-07-15 23:14:55.098175+00
intasend_payout_bank_t3_fee	200.0000	2026-07-15 23:14:55.099361+00
intasend_payout_bank_t4_max	500000.0000	2026-07-15 23:14:55.100607+00
intasend_payout_bank_t4_fee	400.0000	2026-07-15 23:14:55.10176+00
intasend_payout_bank_t5_max	999999.0000	2026-07-15 23:14:55.102873+00
intasend_payout_bank_t5_fee	500.0000	2026-07-15 23:14:55.104022+00
intasend_payout_paybill_t1_max	1000.0000	2026-07-15 23:14:55.105208+00
intasend_payout_paybill_t1_fee	30.0000	2026-07-15 23:14:55.106342+00
intasend_payout_paybill_t2_max	3500.0000	2026-07-15 23:14:55.107481+00
intasend_payout_paybill_t2_fee	50.0000	2026-07-15 23:14:55.108695+00
intasend_payout_paybill_t3_max	5000.0000	2026-07-15 23:14:55.109889+00
intasend_payout_paybill_t3_fee	70.0000	2026-07-15 23:14:55.111453+00
intasend_payout_paybill_t4_max	10000.0000	2026-07-15 23:14:55.112617+00
intasend_payout_paybill_t4_fee	80.0000	2026-07-15 23:14:55.113897+00
intasend_payout_paybill_t5_max	30000.0000	2026-07-15 23:14:55.115816+00
intasend_payout_paybill_t5_fee	100.0000	2026-07-15 23:14:55.117729+00
intasend_payout_paybill_t6_max	45000.0000	2026-07-15 23:14:55.118886+00
intasend_payout_paybill_t6_fee	130.0000	2026-07-15 23:14:55.120017+00
intasend_payout_paybill_t7_max	150000.0000	2026-07-15 23:14:55.121276+00
intasend_payout_paybill_t7_fee	150.0000	2026-07-15 23:14:55.122329+00
intasend_payout_till_threshold	10000.0000	2026-07-15 23:14:55.123441+00
intasend_payout_till_fee_low	20.0000	2026-07-15 23:14:55.124611+00
intasend_payout_till_fee_high	40.0000	2026-07-15 23:14:55.125742+00
intasend_method_paybill_enabled	1.0000	2026-07-15 23:14:55.126882+00
intasend_method_till_enabled	1.0000	2026-07-15 23:14:55.127986+00
\.


--
-- Data for Name: pppoe_invoices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.pppoe_invoices (id, isp_id, subscriber_id, package_id, amount, tax_amount, total_amount, billing_period_start, billing_period_end, due_date, status, paid_at, payment_id, reminder_sent_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: pppoe_packages; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.pppoe_packages (id, isp_id, name, description, price, billing_cycle, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_gb, burst_limit_mbps, burst_threshold_mbps, burst_time_seconds, mikrotik_profile, address_pool, is_active, created_at, updated_at) FROM stdin;
e34d6a4e-4efa-4976-b0a5-3a092e8be68a	15c14766-aa02-4e61-be85-41b79c3ffe85	5Mbps	\N	15.00	monthly	5	5	\N	\N	\N	\N			t	2026-07-31 18:30:33.141978+00	2026-07-31 18:30:33.141978+00
\.


--
-- Data for Name: pppoe_sessions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.pppoe_sessions (id, isp_id, subscriber_id, nas_id, radius_session_id, framed_ip, nas_ip, caller_id, bytes_downloaded, bytes_uploaded, session_time_seconds, status, started_at, ended_at, terminate_cause) FROM stdin;
\.


--
-- Data for Name: pppoe_subscribers; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.pppoe_subscribers (id, isp_id, package_id, nas_id, username, password_hash, full_name, phone, email, id_number, county, town, area, physical_address, static_ip, mac_address, status, balance, next_billing_date, last_payment_date, mikrotik_profile, created_at, updated_at, payment_sms_sent_at, expiry_reminder_sent, is_test, import_batch) FROM stdin;
bb7fc059-20f6-4aec-a7dc-165a415343a6	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	benard	$2a$10$K5U2WulC8jDhjIL32ye6tOFqT3.UFinItM23squ.7mVogKRGMY7U2	benard	0740258495					\N	\N	\N	\N	active	0.00	2026-08-31 18:31:30.115+00	\N	\N	2026-07-31 18:31:30.11611+00	2026-07-31 18:31:30.11611+00	\N	f	f	\N
d657acee-ef81-403c-ba6b-596b3f718d94	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	Jackline	CHANGE_ME_b20ec5	Jackline Mwangangi	0713773260	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-03 14:35:00+00	\N	\N	2026-07-31 22:22:00.526078+00	2026-07-31 22:22:00.526078+00	\N	f	f	imp_1785536520498
71f2077c-fd9a-4f63-a198-c5c896dfdc9d	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	Pauline	CHANGE_ME_6dcc8d	Pauline Njeri	0705519292	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-09 18:02:00+00	\N	\N	2026-07-31 22:22:00.547248+00	2026-07-31 22:22:00.547248+00	\N	f	f	imp_1785536520498
649c5d34-0223-414b-9fbf-5a2adfb43449	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	Hannah	CHANGE_ME_1845e7	Hannah Wambui	0727509143	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-23 14:31:55+00	\N	\N	2026-07-31 22:22:00.556839+00	2026-07-31 22:22:00.556839+00	\N	f	f	imp_1785536520498
07905978-a784-4c59-81fc-536ae3ee10b4	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	miriam	CHANGE_ME_7df4f0	Miriam Wanjiku	0724145513	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-08 15:35:45+00	\N	\N	2026-07-31 22:22:00.565949+00	2026-07-31 22:22:00.565949+00	\N	f	f	imp_1785536520498
6aa9f988-3693-4e48-a988-12c8ebbd00fa	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	shadrack	CHANGE_ME_08e7ec	Shadrack Wanjohi	0701771261	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-14 16:28:13+00	\N	\N	2026-07-31 22:22:00.56761+00	2026-07-31 22:22:00.56761+00	\N	f	f	imp_1785536520498
67222b63-6321-4092-a93c-6f1f7af3dc81	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	lucia	CHANGE_ME_03c074	Lucia Mumbua	0720564724	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-15 09:56:35+00	\N	\N	2026-07-31 22:22:00.57636+00	2026-07-31 22:22:00.57636+00	\N	f	f	imp_1785536520498
8729dfd3-ede6-44a4-ae3e-57b20375a15c	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	andrew	CHANGE_ME_d1edf9	Andrew Mutahi	0721779330	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-16 19:19:52+00	\N	\N	2026-07-31 22:22:00.585324+00	2026-07-31 22:22:00.585324+00	\N	f	f	imp_1785536520498
0377e9fc-1fac-42f9-bf1a-78dba8676afe	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	bena	CHANGE_ME_871940	bena	\N	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-10-20 08:54:00+00	\N	\N	2026-07-31 22:22:00.586762+00	2026-07-31 22:22:00.586762+00	\N	f	f	imp_1785536520498
765e4141-5fc5-48f5-b2e0-0af7d47a7571	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	susan	CHANGE_ME_b657f3	Susan Kahugu	0723544891	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-07 20:28:27+00	\N	\N	2026-07-31 22:22:00.588215+00	2026-07-31 22:22:00.588215+00	\N	f	f	imp_1785536520498
f8962404-d0cc-44c4-8849-9325891cde04	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	george	CHANGE_ME_799bae	George Maina	0722224565	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-07 19:04:31+00	\N	\N	2026-07-31 22:22:00.589595+00	2026-07-31 22:22:00.589595+00	\N	f	f	imp_1785536520498
72fd7606-6934-48a2-89a5-8427dbd89e76	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	margaret	CHANGE_ME_1b24fd	Margaret Mwigai	0759704517	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-03 19:22:15+00	\N	\N	2026-07-31 22:22:00.605545+00	2026-07-31 22:22:00.605545+00	\N	f	f	imp_1785536520498
8bc6897d-056a-4e51-9ad8-217483a6d1d5	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	serah	CHANGE_ME_be33b1	Serah Githiri	0742311552	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-17 14:21:51+00	\N	\N	2026-07-31 22:22:00.607266+00	2026-07-31 22:22:00.607266+00	\N	f	f	imp_1785536520498
c26a0bd2-77cd-4337-897d-3634bc481181	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	joseph	CHANGE_ME_a8676d	Joseph Kariuki	0722388620	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-20 16:45:24+00	\N	\N	2026-07-31 22:22:00.619053+00	2026-07-31 22:22:00.619053+00	\N	f	f	imp_1785536520498
96d3ffae-96f1-4179-a48c-24d9b99f6225	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	timothy	CHANGE_ME_63ce0c	Timothy Wanderi	0113263086	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-22 18:19:00+00	\N	\N	2026-07-31 22:22:00.620605+00	2026-07-31 22:22:00.620605+00	\N	f	f	imp_1785536520498
45bb33a9-499b-43cf-aa97-5312ff26f84f	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	hannah2	CHANGE_ME_fa03ee	Hannah2 Nyambura	0745938920	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-02 19:24:29+00	\N	\N	2026-07-31 22:22:00.622028+00	2026-07-31 22:22:00.622028+00	\N	f	f	imp_1785536520498
f0d7536a-39c2-4a8e-b5cc-928c7e2c5071	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	irene	CHANGE_ME_0cfb80	Irene Wangari	0714849306	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-04 12:58:12+00	\N	\N	2026-07-31 22:22:00.638803+00	2026-07-31 22:22:00.638803+00	\N	f	f	imp_1785536520498
26c18ec8-bb3c-40ba-b87a-dba9cebaf44b	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	orpha	CHANGE_ME_472a1e	Orpha Mutheu	0748723968	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-26 10:29:50+00	\N	\N	2026-07-31 22:22:00.655031+00	2026-07-31 22:22:00.655031+00	\N	f	f	imp_1785536520498
274d82ee-8fb5-416c-b4e8-e1d56b3e7e44	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	albert2	CHANGE_ME_8919b7	Albert2 Macharia	0735947478	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-24 16:55:08+00	\N	\N	2026-07-31 22:22:00.656698+00	2026-07-31 22:22:00.656698+00	\N	f	f	imp_1785536520498
3516bcc5-2931-498a-9ef0-4f12ae8d7369	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	angela	CHANGE_ME_ef06fe	Angela Odhiambo	0720523121	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-26 14:49:58+00	\N	\N	2026-07-31 22:22:00.658116+00	2026-07-31 22:22:00.658116+00	\N	f	f	imp_1785536520498
8385a30d-a387-4be9-9c43-6397316f4915	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	daniel	CHANGE_ME_13bd3c	Daniel	0725707768	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-13 19:10:00+00	\N	\N	2026-07-31 22:22:00.666468+00	2026-07-31 22:22:00.666468+00	\N	f	f	imp_1785536520498
0bbcb911-a49b-48e5-a022-c5a8be8dffaf	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	mikrotiktest2	CHANGE_ME_92b4ec	mikrotiktest2	01171959421	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-31 18:53:00+00	\N	\N	2026-07-31 22:22:00.667873+00	2026-07-31 22:22:00.667873+00	\N	f	f	imp_1785536520498
7c49598b-195a-4b2b-88ef-9f7f019f24be	15c14766-aa02-4e61-be85-41b79c3ffe85	e34d6a4e-4efa-4976-b0a5-3a092e8be68a	\N	daniel2	CHANGE_ME_b4859d	daniel2	07485236481	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-27 18:01:00+00	\N	\N	2026-07-31 22:22:00.714178+00	2026-07-31 22:22:00.714178+00	\N	f	f	imp_1785536520498
\.


--
-- Data for Name: radacct; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radacct (radacctid, acctsessionid, acctuniqueid, username, nasipaddress, nasportid, nasporttype, acctstarttime, acctstoptime, acctinterval, acctsessiontime, acctauthentic, connectinfo_start, connectinfo_stop, acctinputoctets, acctoutputoctets, calledstationid, callingstationid, acctterminatecause, servicetype, framedprotocol, framedipaddress, acctstart_delay, acctdelivery_date, realm, acctupdatetime, framedipv6address, framedipv6prefix, framedinterfaceid, delegatedipv6prefix) FROM stdin;
1	80000029	8764214b21f3eceb3b9652eef25d4d15	R43@98d7ba07	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-31 18:18:06+00	2026-07-31 18:21:41+00	\N	215			\N	13910323	84264066	rl-hotspot	66:87:6A:49:95:DA	Admin-Reboot			10.100.0.245	\N	2026-07-31 18:21:41.330069+00	\N	2026-07-31 18:21:41+00	\N	\N	\N	\N
4	800000bf	ab00cec9238891896673b2401b9c0feb	B1@15c14766	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 06:05:55+00	2026-08-01 06:38:41+00	120	1965				10771638	32755318	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.220	\N	2026-08-01 06:05:56.075483+00	\N	2026-08-01 06:38:41+00	\N	\N	\N	\N
3	800000bc	9439e9aaca1d0b9ebaede8988f092075	B29@15c14766	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 04:23:02+00	2026-08-01 04:41:38+00	120	1115				1766794	12817330	rl-hotspot	3A:AD:23:80:40:76	Lost-Service			10.100.0.216	\N	2026-08-01 04:23:03.104526+00	\N	2026-08-01 04:41:38+00	\N	\N	\N	\N
2	81000783	58f95013f0cba2fa589309c8c3a01d61	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-01 01:35:43+00	\N	300	34506	RADIUS		\N	36708713	373689710	rumalink	50:0F:F5:36:A7:50	\N	Framed-User	PPP	100.64.0.254	\N	2026-08-01 01:35:43.953344+00	\N	2026-08-01 11:10:44+00	\N	\N	\N	\N
5	800000c1	491fd5006ec085399158269d02bd1e9a	B31@15c14766	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 06:19:28+00	2026-08-01 07:19:25+00	120	3597				5604914	119299586	rl-hotspot	9E:A0:95:3A:BF:8D	Session-Timeout			10.100.0.214	\N	2026-08-01 06:19:28.805839+00	\N	2026-08-01 07:19:25+00	\N	\N	\N	\N
\.


--
-- Data for Name: radcheck; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radcheck (id, username, attribute, op, value) FROM stdin;
1	benard	Cleartext-Password	:=	benard2541028
2	benard	NT-Password	:=	0B340A7005F4C900BF15E1D362239383
9	B3@15c14766	Cleartext-Password	:=	85ydb9
10	B4@15c14766	Cleartext-Password	:=	fyd7ab
19	B13@15c14766	Cleartext-Password	:=	6bf2ce
21	B15@15c14766	Cleartext-Password	:=	ddff5c
22	B16@15c14766	Cleartext-Password	:=	f82xe6
28	B22@15c14766	Cleartext-Password	:=	b6ee7x
33	B27@15c14766	Cleartext-Password	:=	3y7b8d
\.


--
-- Data for Name: radcheck_delete_audit; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.radcheck_delete_audit (id, deleted_at, username, app_name, client_addr, backend_pid, query_text) FROM stdin;
1	2026-07-24 14:12:02.404139+00	R1@4742d080	psql	\N	26265	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
2	2026-07-24 14:13:02.177616+00	R1@4742d080	psql	\N	26342	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
3	2026-07-24 14:14:02.323813+00	R1@4742d080	psql	\N	26417	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
4	2026-07-24 14:15:02.205289+00	R1@4742d080	psql	\N	26493	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
5	2026-07-24 14:16:02.023408+00	R1@4742d080	psql	\N	26561	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
6	2026-07-24 14:17:01.602301+00	R1@4742d080	psql	\N	26714	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
7	2026-07-24 14:18:02.647098+00	R1@4742d080	psql	\N	26790	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
8	2026-07-24 14:19:02.235129+00	R1@4742d080	psql	\N	26857	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
9	2026-07-24 14:20:02.571804+00	R1@4742d080	psql	\N	27008	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
10	2026-07-24 14:21:01.372115+00	R1@4742d080	psql	\N	27078	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
11	2026-07-24 14:22:02.206022+00	R1@4742d080	psql	\N	27155	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
12	2026-07-24 14:23:01.945059+00	R1@4742d080	psql	\N	27223	DELETE FROM radcheck\nWHERE username NOT LIKE 'K%@%'\n  AND username NOT LIKE 'K%'\n    AND username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries\n  AND NOT EXISTS (\n    SELECT 1 FROM pppoe_subscribers ps\n    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')\n  );
13	2026-07-24 14:27:01.612163+00	R1@4742d080		127.0.0.1	27588	DELETE FROM radcheck WHERE username = $1 OR username = $2
14	2026-07-24 14:27:49.042687+00	R1@4742d080		127.0.0.1	27586	DELETE FROM radcheck WHERE username = $1
15	2026-07-24 14:28:49.044839+00	R1@4742d080		127.0.0.1	27661	DELETE FROM radcheck WHERE username = $1
16	2026-07-24 14:49:08.768476+00	R1@4742d080		127.0.0.1	29855	DELETE FROM radcheck WHERE username = $1
17	2026-07-24 14:50:00.811112+00	R1@4742d080		127.0.0.1	29855	DELETE FROM radcheck WHERE username = $1 OR username = $2
18	2026-07-24 14:53:21.607466+00	R1@4742d080		127.0.0.1	30261	DELETE FROM radcheck WHERE username = $1 OR username = $2
19	2026-07-24 14:53:40.842547+00	R1@4742d080		127.0.0.1	30260	DELETE FROM radcheck WHERE username = $1
20	2026-07-24 14:54:23.664188+00	R1@4742d080		127.0.0.1	30334	DELETE FROM radcheck WHERE username = $1
21	2026-07-24 14:54:40.847506+00	R1@4742d080		127.0.0.1	30333	DELETE FROM radcheck WHERE username = $1
22	2026-07-24 14:55:40.843341+00	R1@4742d080		127.0.0.1	30419	DELETE FROM radcheck WHERE username = $1
23	2026-07-24 14:56:00.998495+00	R1@4742d080		127.0.0.1	30418	DELETE FROM radcheck WHERE username = $1 OR username = $2
24	2026-07-24 15:00:59.198746+00	R2@4742d080		127.0.0.1	30840	DELETE FROM radcheck WHERE username = $1
25	2026-07-24 15:00:59.395255+00	R2@4742d080		127.0.0.1	30840	DELETE FROM radcheck WHERE username = $1
26	2026-07-24 15:01:00.17784+00	R2@4742d080		127.0.0.1	30774	DELETE FROM radcheck WHERE username = $1 OR username = $2
27	2026-07-24 15:18:52.837098+00	R1@4742d080		127.0.0.1	32507	DELETE FROM radcheck WHERE username = $1 OR username = $2
28	2026-07-24 15:18:52.914469+00	R1@4742d080		127.0.0.1	32507	DELETE FROM radcheck WHERE username = $1
29	2026-07-24 15:21:52.17838+00	R1@4742d080		127.0.0.1	32739	DELETE FROM radcheck WHERE username = $1 OR username = $2
30	2026-07-24 15:21:56.185925+00	8E:DD:81:17:79:C6		127.0.0.1	32739	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
31	2026-07-24 15:22:06.010325+00	R1@4742d080		127.0.0.1	32745	DELETE FROM radcheck WHERE username = $1
32	2026-07-24 15:23:06.01868+00	R1@4742d080		127.0.0.1	32813	DELETE FROM radcheck WHERE username = $1
33	2026-07-24 15:50:00.164645+00	R1@4742d080		127.0.0.1	35509	DELETE FROM radcheck WHERE username = $1 OR username = $2
34	2026-07-24 15:50:13.982347+00	66:87:6A:49:95:DA		127.0.0.1	35583	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
35	2026-07-24 15:52:00.839958+00	R1@4742d080		127.0.0.1	35662	DELETE FROM radcheck WHERE username = $1 OR username = $2
36	2026-07-25 05:50:59.268425+00	66:87:6A:49:95:DA		127.0.0.1	100774	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
37	2026-07-25 05:52:59.303869+00	8E:DD:81:17:79:C6		127.0.0.1	100880	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
38	2026-07-25 06:07:58.568943+00	R1@4742d080		127.0.0.1	101986	DELETE FROM radcheck WHERE username = $1
39	2026-07-25 06:08:58.572834+00	R1@4742d080		127.0.0.1	102170	DELETE FROM radcheck WHERE username = $1
40	2026-07-25 06:15:02.99937+00	R3@4742d080		127.0.0.1	103799	DELETE FROM radcheck WHERE username = $1
41	2026-07-25 06:15:03.501408+00	R3@4742d080		127.0.0.1	103799	DELETE FROM radcheck WHERE username = $1
42	2026-07-25 06:15:03.703977+00	R3@4742d080		127.0.0.1	103799	DELETE FROM radcheck WHERE username = $1
43	2026-07-25 06:16:03.341733+00	R3@4742d080		127.0.0.1	103891	DELETE FROM radcheck WHERE username = $1 OR username = $2
44	2026-07-25 15:01:01.740425+00	R2@4742d080	psql	\N	157177	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
45	2026-07-25 15:51:55.486476+00	66:87:6A:49:95:DA		127.0.0.1	162032	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
46	2026-07-25 15:52:01.839856+00	R1@4742d080	psql	\N	162074	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
47	2026-07-26 06:16:01.32502+00	R3@4742d080	psql	\N	48562	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
48	2026-07-26 13:40:07.011693+00	R4@4742d080		127.0.0.1	92303	DELETE FROM radcheck WHERE username = $1 OR username = $2
49	2026-07-26 18:40:21.897129+00	3A:AD:23:80:40:76		127.0.0.1	121251	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
50	2026-07-26 18:41:01.963796+00	R4@4742d080	psql	\N	121378	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
51	2026-07-28 06:59:18.984584+00	R1@4742d080		127.0.0.1	129556	DELETE FROM radcheck WHERE username = $1 OR username = $2
52	2026-07-28 06:59:21.713499+00	66:87:6A:49:95:DA		127.0.0.1	129556	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
53	2026-07-28 07:18:47.65754+00	R3@4742d080		127.0.0.1	131764	DELETE FROM radcheck WHERE username = $1
54	2026-07-28 07:28:49.402769+00	R1@4742d080		127.0.0.1	132719	DELETE FROM radcheck WHERE username = $1
55	2026-07-28 07:29:00.992664+00	R1@4742d080		127.0.0.1	132809	DELETE FROM radcheck WHERE username = $1 OR username = $2
56	2026-07-29 04:28:28.875823+00	R1@4742d080		127.0.0.1	98807	DELETE FROM radcheck WHERE username = $1 OR username = $2
57	2026-07-29 04:28:38.196187+00	66:87:6A:49:95:DA		127.0.0.1	98897	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
58	2026-07-29 05:13:55.442851+00	R1@4742d080		127.0.0.1	103557	DELETE FROM radcheck WHERE username = $1 OR username = $2
59	2026-07-29 05:14:38.17738+00	66:87:6A:49:95:DA		127.0.0.1	103653	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
60	2026-07-29 05:27:22.032711+00	R1@4742d080		127.0.0.1	105044	DELETE FROM radcheck WHERE username = $1
61	2026-07-29 05:28:00.146342+00	R1@4742d080		127.0.0.1	105132	DELETE FROM radcheck WHERE username = $1 OR username = $2
62	2026-07-29 05:54:37.947175+00	R1@4742d080		127.0.0.1	107625	DELETE FROM radcheck WHERE username = $1
63	2026-07-29 05:55:37.943418+00	R1@4742d080		127.0.0.1	107738	DELETE FROM radcheck WHERE username = $1
64	2026-07-29 06:29:03.890552+00	R1@44a1539e		127.0.0.1	110402	DELETE FROM radcheck WHERE username = $1
65	2026-07-29 06:29:11.948237+00	R1@44a1539e		127.0.0.1	110402	DELETE FROM radcheck WHERE username = $1
66	2026-07-29 06:30:00.595341+00	R1@44a1539e		127.0.0.1	118060	DELETE FROM radcheck WHERE username = $1 OR username = $2
67	2026-07-29 08:59:00.784929+00	R4@44a1539e		127.0.0.1	132607	DELETE FROM radcheck WHERE username = $1 OR username = $2
68	2026-07-29 09:38:32.367997+00	R3@44a1539e		127.0.0.1	136839	DELETE FROM radcheck WHERE username = $1
69	2026-07-29 09:39:00.773104+00	R3@44a1539e		127.0.0.1	136926	DELETE FROM radcheck WHERE username = $1 OR username = $2
70	2026-07-29 09:54:22.553383+00	R3@44a1539e		127.0.0.1	138605	DELETE FROM radcheck WHERE username = $1
71	2026-07-29 09:54:56.551721+00	R3@44a1539e		127.0.0.1	138605	DELETE FROM radcheck WHERE username = $1
72	2026-07-29 09:55:56.549973+00	R3@44a1539e		127.0.0.1	138696	DELETE FROM radcheck WHERE username = $1
73	2026-07-29 09:56:00.674876+00	R3@44a1539e		127.0.0.1	138785	DELETE FROM radcheck WHERE username = $1 OR username = $2
74	2026-07-29 09:58:56.548591+00	3A:AD:23:80:40:76		127.0.0.1	138990	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
75	2026-07-29 09:59:02.217535+00	R4@44a1539e	psql	\N	139115	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
76	2026-07-29 10:09:58.577896+00	R3@44a1539e		127.0.0.1	140398	DELETE FROM radcheck WHERE username = $1
77	2026-07-29 10:10:00.987979+00	R3@44a1539e		127.0.0.1	140401	DELETE FROM radcheck WHERE username = $1 OR username = $2
78	2026-07-29 10:12:11.766902+00	R3@44a1539e		127.0.0.1	140691	DELETE FROM radcheck WHERE username = $1 OR username = $2
79	2026-07-29 10:12:56.55554+00	BC:2B:02:3A:7F:7C		127.0.0.1	140598	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
80	2026-07-29 10:14:15.690284+00	R3@44a1539e		127.0.0.1	140894	DELETE FROM radcheck WHERE username = $1
81	2026-07-29 10:15:00.135242+00	R3@44a1539e		127.0.0.1	140894	DELETE FROM radcheck WHERE username = $1 OR username = $2
82	2026-07-29 10:28:22.576623+00	R3@44a1539e		127.0.0.1	142594	DELETE FROM radcheck WHERE username = $1
83	2026-07-29 10:29:00.510709+00	R3@44a1539e		127.0.0.1	142684	DELETE FROM radcheck WHERE username = $1 OR username = $2
84	2026-07-29 10:31:56.568283+00	R3@44a1539e		127.0.0.1	142875	DELETE FROM radcheck WHERE username = $1
85	2026-07-29 10:33:27.071293+00	R3@44a1539e		127.0.0.1	143079	DELETE FROM radcheck WHERE username = $1
86	2026-07-29 10:34:00.671777+00	R3@44a1539e		127.0.0.1	143079	DELETE FROM radcheck WHERE username = $1 OR username = $2
87	2026-07-29 10:49:16.427826+00	R6@44a1539e		127.0.0.1	144851	DELETE FROM radcheck WHERE username = $1
88	2026-07-29 10:50:13.295514+00	R6@44a1539e		127.0.0.1	144947	DELETE FROM radcheck WHERE username = $1 OR username = $2
89	2026-07-29 11:33:51.130807+00	BC:2B:02:3A:7F:7C		127.0.0.1	149113	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
90	2026-07-29 11:34:01.908114+00	R3@44a1539e	psql	\N	149235	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
91	2026-07-29 11:49:51.134106+00	9E:A0:95:3A:BF:8D		127.0.0.1	150645	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
92	2026-07-29 11:50:02.498424+00	R6@44a1539e	psql	\N	150773	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
93	2026-07-29 13:46:38.498546+00	R6@44a1539e		127.0.0.1	162045	DELETE FROM radcheck WHERE username = $1
94	2026-07-29 13:48:13.757314+00	R6@44a1539e		127.0.0.1	162336	DELETE FROM radcheck WHERE username = $1 OR username = $2
95	2026-07-29 14:47:01.4162+00	R6@44a1539e	psql	\N	168246	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
96	2026-07-29 19:29:04.745928+00	R7@44a1539e		127.0.0.1	194665	DELETE FROM radcheck WHERE username = $1
97	2026-07-29 19:30:00.431458+00	R7@44a1539e		127.0.0.1	194665	DELETE FROM radcheck WHERE username = $1 OR username = $2
98	2026-07-29 19:31:00.447352+00	R8@44a1539e		127.0.0.1	194665	DELETE FROM radcheck WHERE username = $1 OR username = $2
99	2026-07-29 20:29:38.678305+00	A6:0B:69:D9:3A:6D		127.0.0.1	200467	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
100	2026-07-29 20:30:02.375368+00	R7@44a1539e	psql	\N	200599	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
101	2026-07-29 20:31:02.271099+00	R8@44a1539e	psql	\N	200694	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
102	2026-07-29 20:31:38.679205+00	CE:C4:E5:8C:D3:53		127.0.0.1	200659	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
103	2026-07-30 06:29:38.949048+00	66:87:6A:49:95:DA		127.0.0.1	258858	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
104	2026-07-30 06:30:02.7341+00	R1@44a1539e	psql	\N	258979	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
105	2026-07-30 08:12:55.267792+00	R6@44a1539e		127.0.0.1	268567	DELETE FROM radcheck WHERE username = $1
106	2026-07-30 08:13:09.75131+00	R6@44a1539e		127.0.0.1	268762	DELETE FROM radcheck WHERE username = $1 OR username = $2
107	2026-07-30 14:24:23.532558+00	R6@44a1539e		127.0.0.1	305141	DELETE FROM radcheck WHERE username = $1 OR username = $2
108	2026-07-30 14:28:12.638789+00	R1@44a1539e		127.0.0.1	305536	DELETE FROM radcheck WHERE username = $1
109	2026-07-30 14:28:12.650958+00	66:87:6A:49:95:DA		127.0.0.1	305536	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
110	2026-07-30 14:30:00.795711+00	R1@44a1539e		127.0.0.1	305723	DELETE FROM radcheck WHERE username = $1 OR username = $2
111	2026-07-30 14:30:11.584233+00	R6@44a1539e		127.0.0.1	305723	DELETE FROM radcheck WHERE username = $1 OR username = $2
112	2026-07-30 14:30:12.638504+00	R6@44a1539e		127.0.0.1	305729	DELETE FROM radcheck WHERE username = $1
113	2026-07-30 14:31:12.638382+00	R6@44a1539e		127.0.0.1	305819	DELETE FROM radcheck WHERE username = $1
114	2026-07-30 14:32:11.442564+00	R1@44a1539e		127.0.0.1	305911	DELETE FROM radcheck WHERE username = $1
115	2026-07-30 14:33:00.875953+00	R1@44a1539e		127.0.0.1	305910	DELETE FROM radcheck WHERE username = $1 OR username = $2
116	2026-07-30 15:30:02.525641+00	R6@44a1539e	psql	\N	312292	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
117	2026-07-30 15:32:59.838808+00	66:87:6A:49:95:DA		127.0.0.1	312353	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
118	2026-07-30 15:33:01.696331+00	R1@44a1539e	psql	\N	312581	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
119	2026-07-30 17:21:10.916931+00	R6@44a1539e		127.0.0.1	323755	DELETE FROM radcheck WHERE username = $1 OR username = $2
120	2026-07-31 11:12:03.90075+00	R1@98d7ba07		127.0.0.1	21031	DELETE FROM radcheck WHERE username = $1 OR username = $2
121	2026-07-31 11:15:03.079935+00	R1@98d7ba07		127.0.0.1	21285	DELETE FROM radcheck WHERE username = $1
122	2026-07-31 11:15:11.098883+00	R1@98d7ba07		127.0.0.1	21285	DELETE FROM radcheck WHERE username = $1
123	2026-07-31 11:16:00.748546+00	R1@98d7ba07		127.0.0.1	21281	DELETE FROM radcheck WHERE username = $1 OR username = $2
124	2026-07-31 12:12:02.327272+00	K1@98d7ba07	psql	\N	27144	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
125	2026-07-31 12:15:19.224788+00	66:87:6A:49:95:DA		127.0.0.1	27536	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
126	2026-07-31 12:16:01.890375+00	R1@98d7ba07	psql	\N	27664	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
127	2026-07-31 12:57:00.608735+00	R1@98d7ba07		127.0.0.1	31994	DELETE FROM radcheck WHERE username = $1 OR username = $2
128	2026-07-31 13:57:02.113284+00	R1@98d7ba07	psql	\N	37451	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
129	2026-07-31 13:57:28.790809+00	66:87:6A:49:95:DA		127.0.0.1	37418	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
130	2026-07-31 17:09:48.025504+00	R3@98d7ba07		127.0.0.1	54388	DELETE FROM radcheck WHERE username = $1
131	2026-07-31 17:10:03.57332+00	R3@98d7ba07		127.0.0.1	54455	DELETE FROM radcheck WHERE username = $1 OR username = $2
132	2026-07-31 17:25:36.974024+00	66:87:6A:49:95:DA		127.0.0.1	56139	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
133	2026-07-31 17:27:36.871286+00	R3@98d7ba07		127.0.0.1	56246	DELETE FROM radcheck WHERE username = $1
134	2026-07-31 17:27:43.481251+00	R3@98d7ba07		127.0.0.1	56246	DELETE FROM radcheck WHERE username = $1
135	2026-07-31 17:28:14.129293+00	R3@98d7ba07		127.0.0.1	56319	DELETE FROM radcheck WHERE username = $1 OR username = $2
136	2026-07-31 17:29:45.520969+00	R3@98d7ba07		127.0.0.1	56460	DELETE FROM radcheck WHERE username = $1 OR username = $2
137	2026-07-31 17:33:05.384754+00	R3@98d7ba07		127.0.0.1	56726	DELETE FROM radcheck WHERE username = $1 OR username = $2
138	2026-07-31 17:34:50.991859+00	R1@98d7ba07		127.0.0.1	56815	DELETE FROM radcheck WHERE username = $1
139	2026-07-31 17:35:00.199849+00	R1@98d7ba07		127.0.0.1	56814	DELETE FROM radcheck WHERE username = $1 OR username = $2
140	2026-07-31 18:16:40.496751+00	R1@98d7ba07		127.0.0.1	61408	DELETE FROM radcheck WHERE username = $1 OR username = $2
141	2026-07-31 18:17:30.00774+00	66:87:6A:49:95:DA		127.0.0.1	61555	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
142	2026-07-31 18:42:00.15369+00	B1@15c14766		127.0.0.1	63749	DELETE FROM radcheck WHERE username = $1 OR username = $2
143	2026-07-31 19:08:42.052554+00	B1@15c14766		127.0.0.1	66537	DELETE FROM radcheck WHERE username = $1
144	2026-07-31 19:09:00.815479+00	B1@15c14766		127.0.0.1	66537	DELETE FROM radcheck WHERE username = $1 OR username = $2
145	2026-07-31 20:09:01.727392+00	B1@15c14766	psql	\N	72723	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
146	2026-07-31 20:09:30.142196+00	66:87:6A:49:95:DA		127.0.0.1	72690	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
147	2026-07-31 23:00:02.707703+00	B17@15c14766	psql	\N	95159	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
148	2026-07-31 23:07:02.224155+00	B23@15c14766	psql	\N	96793	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
149	2026-07-31 23:09:01.524461+00	B21@15c14766	psql	\N	97250	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
150	2026-08-01 00:44:02.02337+00	B18@15c14766	psql	\N	119360	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
175	2026-08-01 07:19:35.535216+00	9E:A0:95:3A:BF:8D		127.0.0.1	212842	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
151	2026-08-01 02:10:01.420901+00	B28@15c14766	psql	\N	139643	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
152	2026-08-01 02:14:02.273252+00	B24@15c14766	psql	\N	140565	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
153	2026-08-01 04:08:01.59639+00	B9@15c14766	psql	\N	167150	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
154	2026-08-01 04:22:01.662391+00	B25@15c14766	psql	\N	170525	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
155	2026-08-01 04:24:00.637771+00	B30@15c14766		127.0.0.1	170731	DELETE FROM radcheck WHERE username = $1 OR username = $2
156	2026-08-01 04:39:01.455261+00	B11@15c14766	psql	\N	174507	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
157	2026-08-01 04:44:02.052187+00	B5@15c14766	psql	\N	175668	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
158	2026-08-01 04:57:01.791558+00	B10@15c14766	psql	\N	178699	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
159	2026-08-01 04:57:01.791558+00	B14@15c14766	psql	\N	178699	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
160	2026-08-01 05:23:02.227166+00	B2@15c14766	psql	\N	184811	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
161	2026-08-01 05:23:02.227166+00	B29@15c14766	psql	\N	184811	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
162	2026-08-01 05:23:02.227166+00	B30@15c14766	psql	\N	184811	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
163	2026-08-01 05:23:03.282249+00	3A:AD:23:80:40:76		127.0.0.1	184774	\n        WITH expired AS (\n          SELECT used_by_mac AS m FROM hotspot_vouchers\n           WHERE status='expired' AND used_by_mac IS NOT NULL AND used_by_mac <> ''\n             AND expires_at IS NOT NULL AND expires_at < NOW()\n        ),\n        forms AS (\n          SELECT lower(m) AS mform FROM expired\n          UNION SELECT upper(m) FROM expired\n        )\n        DELETE FROM radcheck WHERE username IN (SELECT mform FROM forms) RETURNING username\n      
164	2026-08-01 05:34:02.281235+00	B19@15c14766	psql	\N	187363	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
165	2026-08-01 05:53:01.299638+00	B8@15c14766	psql	\N	191817	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
166	2026-08-01 05:58:01.684503+00	B26@15c14766	psql	\N	192981	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
167	2026-08-01 06:06:00.253608+00	B1@15c14766		127.0.0.1	194802	DELETE FROM radcheck WHERE username = $1 OR username = $2
168	2026-08-01 06:20:00.691518+00	B31@15c14766		127.0.0.1	197879	DELETE FROM radcheck WHERE username = $1 OR username = $2
169	2026-08-01 06:37:01.328248+00	B6@15c14766	psql	\N	202121	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
170	2026-08-01 06:38:37.78318+00	B1@15c14766		127.0.0.1	202326	DELETE FROM radcheck WHERE username = $1 OR username = $2
171	2026-08-01 06:39:35.525049+00	66:87:6A:49:95:DA		127.0.0.1	202546	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
172	2026-08-01 06:43:10.838777+00	B32@15c14766		127.0.0.1	203490	DELETE FROM radcheck WHERE username = $1 OR username = $2
173	2026-08-01 06:52:01.775238+00	B20@15c14766	psql	\N	205622	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
174	2026-08-01 07:11:01.320029+00	B7@15c14766	psql	\N	210943	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
176	2026-08-01 07:20:02.605084+00	B31@15c14766	psql	\N	213125	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
177	2026-08-01 07:43:01.626578+00	B32@15c14766	psql	\N	218577	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
178	2026-08-01 09:28:02.210503+00	B12@15c14766	psql	\N	243383	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
\.


--
-- Data for Name: radgroupcheck; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radgroupcheck (id, groupname, attribute, op, value) FROM stdin;
\.


--
-- Data for Name: radgroupreply; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radgroupreply (id, groupname, attribute, op, value) FROM stdin;
\.


--
-- Data for Name: radpostauth; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radpostauth (id, username, pass, reply, authdate, class) FROM stdin;
1	benard		Access-Accept	2026-08-01 01:35:43.76546+00	\N
2	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 01:36:04.257085+00	\N
3	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 01:38:03.390496+00	\N
4	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 02:05:02.258163+00	\N
5	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 02:21:30.90251+00	\N
6	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 02:40:06.00129+00	\N
7	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 03:02:54.173586+00	\N
8	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 03:25:37.598412+00	\N
9	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 03:35:09.236055+00	\N
10	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 03:44:22.731161+00	\N
11	3A:AD:23:80:40:76	RLMACAUTH	Access-Reject	2026-08-01 04:22:23.664379+00	\N
12	B29@15c14766	3ee53e	Access-Accept	2026-08-01 04:23:02.865638+00	\N
13	BC:BD:9E:70:FA:C2	RLMACAUTH	Access-Reject	2026-08-01 04:31:03.771829+00	\N
14	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 06:05:17.171575+00	\N
15	B1@15c14766	c5ye9c	Access-Accept	2026-08-01 06:05:55.864621+00	\N
16	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-08-01 06:16:02.102431+00	\N
17	B31@15c14766	y9fce4	Access-Accept	2026-08-01 06:19:28.597477+00	\N
18	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-08-01 06:39:39.594528+00	\N
19	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-08-01 07:43:02.956416+00	\N
\.


--
-- Data for Name: radreply; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radreply (id, username, attribute, op, value) FROM stdin;
366	B3@15c14766	Session-Timeout	:=	209995
367	B3@15c14766	Mikrotik-Rate-Limit	:=	5M/5M
368	B4@15c14766	Session-Timeout	:=	494945
369	B4@15c14766	Mikrotik-Rate-Limit	:=	5M/5M
18670	benard	Mikrotik-Rate-Limit	= 	5M/5M
18671	Jackline	Mikrotik-Rate-Limit	= 	5M/5M
386	B13@15c14766	Session-Timeout	:=	66255
387	B13@15c14766	Mikrotik-Rate-Limit	:=	5M/5M
390	B15@15c14766	Session-Timeout	:=	60258
391	B15@15c14766	Mikrotik-Rate-Limit	:=	5M/5M
392	B16@15c14766	Session-Timeout	:=	67711
393	B16@15c14766	Mikrotik-Rate-Limit	:=	5M/5M
18672	Pauline	Mikrotik-Rate-Limit	= 	5M/5M
18673	Hannah	Mikrotik-Rate-Limit	= 	5M/5M
18674	miriam	Mikrotik-Rate-Limit	= 	5M/5M
18675	shadrack	Mikrotik-Rate-Limit	= 	5M/5M
18676	lucia	Mikrotik-Rate-Limit	= 	5M/5M
18677	andrew	Mikrotik-Rate-Limit	= 	5M/5M
404	B22@15c14766	Session-Timeout	:=	65026
405	B22@15c14766	Mikrotik-Rate-Limit	:=	5M/5M
18678	bena	Mikrotik-Rate-Limit	= 	5M/5M
18679	susan	Mikrotik-Rate-Limit	= 	5M/5M
18680	george	Mikrotik-Rate-Limit	= 	5M/5M
18681	margaret	Mikrotik-Rate-Limit	= 	5M/5M
18682	serah	Mikrotik-Rate-Limit	= 	5M/5M
18683	joseph	Mikrotik-Rate-Limit	= 	5M/5M
18684	timothy	Mikrotik-Rate-Limit	= 	5M/5M
18685	hannah2	Mikrotik-Rate-Limit	= 	5M/5M
414	B27@15c14766	Session-Timeout	:=	62996
415	B27@15c14766	Mikrotik-Rate-Limit	:=	5M/5M
18686	irene	Mikrotik-Rate-Limit	= 	5M/5M
18687	orpha	Mikrotik-Rate-Limit	= 	5M/5M
18688	albert2	Mikrotik-Rate-Limit	= 	5M/5M
18689	angela	Mikrotik-Rate-Limit	= 	5M/5M
18690	daniel	Mikrotik-Rate-Limit	= 	5M/5M
18691	mikrotiktest2	Mikrotik-Rate-Limit	= 	5M/5M
18692	daniel2	Mikrotik-Rate-Limit	= 	5M/5M
\.


--
-- Data for Name: radusergroup; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radusergroup (username, groupname, priority) FROM stdin;
\.


--
-- Data for Name: shop_categories; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_categories (id, name, slug, sort_order, is_active, created_at) FROM stdin;
537d7139-6d7e-4669-a193-4c27b400c0ff	Routers	routers	1	t	2026-07-01 23:00:28.454669+00
f1de54a8-b025-4e88-b713-52a0f376c7d4	Antennas	antennas	2	t	2026-07-01 23:00:28.454669+00
2b662eaf-8508-4b99-b479-867355860290	Cables & Connectors	cables-connectors	3	t	2026-07-01 23:00:28.454669+00
db8ad8db-c06a-4d93-9be9-2b018fac5707	Accessories	accessories	4	t	2026-07-01 23:00:28.454669+00
\.


--
-- Data for Name: shop_order_items; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_order_items (id, order_id, product_id, product_name, unit_price, quantity, line_total, created_at, product_image) FROM stdin;
\.


--
-- Data for Name: shop_orders; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_orders (id, order_number, customer_name, customer_phone, customer_email, delivery_address, delivery_notes, subtotal, delivery_fee, total, status, payment_status, mpesa_checkout_id, mpesa_receipt, paid_at, notified_admin, metadata, created_at, updated_at, delivery_type, delivery_location, map_location, admin_seen) FROM stdin;
\.


--
-- Data for Name: shop_payments; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_payments (id, order_id, amount, phone_number, mpesa_checkout_id, mpesa_receipt, status, raw_callback, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: shop_products; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_products (id, category_id, name, slug, description, price, compare_price, sku, stock_qty, track_stock, image_url, images, is_active, is_featured, weight_kg, created_at, updated_at, supplier_name, supplier_phone, supplier_price) FROM stdin;
ed29d286-5e56-4a13-9390-3b8daced26c6	537d7139-6d7e-4669-a193-4c27b400c0ff	China Mobile	china-mobile	Wall Breaker	15.00	\N	\N	47	t	/uploads/products/prod_1782981577338_883042.webp	[]	t	f	\N	2026-07-02 08:40:00.781026+00	2026-07-02 08:40:00.781026+00	Me	0740258495	10.00
1666f7e3-8782-47a4-a1fb-a3922cb4f59e	537d7139-6d7e-4669-a193-4c27b400c0ff	TP-Link	tp-link	Upto 300Mbps	10.00	\N	\N	39	t	/uploads/products/prod_1782977765100_426047.webp	[]	t	f	\N	2026-07-02 07:36:24.992146+00	2026-07-02 07:38:09.531926+00	\N	\N	\N
\.


--
-- Data for Name: shop_settings; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.shop_settings (id, default_delivery_fee, free_delivery_over, currency, shop_enabled, whatsapp_enabled, whatsapp_phone_id, whatsapp_token, whatsapp_admin_numbers, order_prefix, updated_at, free_delivery_locations) FROM stdin;
1	0.00	4000.00	KES	t	f	\N	\N		RL	2026-07-02 08:16:57.534298+00	Nairobi CBD, Dandora, Kasarani
\.


--
-- Data for Name: sms_credit_transactions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_credit_transactions (id, isp_id, txn_type, sms_count, unit_price, unit_cost, amount_paid, profit, isp_balance_after, payment_id, status, note, created_at) FROM stdin;
1972d39d-be50-454d-87a2-23df44a22eee	15c14766-aa02-4e61-be85-41b79c3ffe85	signup_bonus	50.0000	\N	\N	\N	\N	50.0000	\N	completed	Welcome bonus on signup	2026-07-31 18:23:18.913522+00
11934615-a69e-4fb1-ab16-82802b12661d	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	49.0000	\N	completed	SMS sent	2026-07-31 18:23:59.650026+00
39c78568-074e-4f9a-b522-b7f8bffd8244	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	48.0000	\N	completed	SMS sent	2026-07-31 18:42:00.365053+00
fa1e498e-c7ab-4a3e-96b6-de3c5d9d1dc0	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	47.0000	\N	completed	SMS sent	2026-07-31 19:09:01.007151+00
73e94064-69ac-44f3-91c3-9230f8e4d930	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	46.0000	\N	completed	SMS sent	2026-08-01 04:23:01.408934+00
4f4f30f6-613c-4f22-b468-b3455001918b	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	45.0000	\N	completed	SMS sent	2026-08-01 04:23:01.411474+00
bdeaaa46-784d-4fcb-b22e-4d25f70a7e53	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	44.0000	\N	completed	SMS sent	2026-08-01 06:06:00.472625+00
6d458a08-8cdc-4d25-8721-fcbe8a7aa235	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	43.0000	\N	completed	SMS sent	2026-08-01 06:19:20.243503+00
45f49c2a-31ae-41f4-926d-701f1ce02a1d	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	42.0000	\N	completed	SMS sent	2026-08-01 06:42:52.99359+00
a194ac30-faf6-48d2-959d-821370361cda	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	41.0000	\N	completed	SMS sent	2026-08-01 11:15:20.384652+00
d6f676d6-c59c-437b-99c4-876b296ae680	15c14766-aa02-4e61-be85-41b79c3ffe85	consumption	-1.0000	\N	\N	\N	\N	40.0000	\N	completed	SMS sent	2026-08-01 11:17:04.429015+00
\.


--
-- Data for Name: sms_logs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_logs (id, isp_id, recipient, message, gateway, gateway_message_id, status, cost, sent_at) FROM stdin;
a071ff08-d424-496d-bc0e-f3940360b40a	15c14766-aa02-4e61-be85-41b79c3ffe85	254704994652	Your RumaLink verification code is 795928. It expires in 10 minutes. Do not share it.	rumalink	\N	sent	\N	2026-07-31 18:23:59.652597+00
279a6e93-2406-4a0e-a89f-2a308da2371e	15c14766-aa02-4e61-be85-41b79c3ffe85	254740258495	bonte: 1 Hour activated.\nUsername: B1\nPassword: c5ye9c\nExpires: 31 Jul 2026, 22:41\nReceipt: UGV1313N78	rumalink	\N	sent	\N	2026-07-31 18:42:00.367264+00
d048399c-9539-479b-9cc9-281aad7220d9	15c14766-aa02-4e61-be85-41b79c3ffe85	254740258495	bonte: 1 Hour activated.\nUsername: B1\nPassword: c5ye9c\nExpires: 31 Jul 2026, 23:08\nReceipt: UGV1313SO9	rumalink	\N	sent	\N	2026-07-31 19:09:01.008871+00
6fadbd81-8368-47af-a653-5ec94edaf03e	15c14766-aa02-4e61-be85-41b79c3ffe85	254796829688	bonte: 1 Hour activated.\nUsername: B30\nPassword: yx6dxa\nExpires: 01 Aug 2026, 08:23\nReceipt: UH1JK11WU4	rumalink	\N	sent	\N	2026-08-01 04:23:01.412841+00
02e63c1c-6b56-4e71-99c9-10c2cc1b5d71	15c14766-aa02-4e61-be85-41b79c3ffe85	254796829688	bonte: 1 Hour activated.\nUsername: B30\nPassword: yx6dxa\nExpires: 01 Aug 2026, 08:23\nReceipt: UH1JK11WU4	rumalink	\N	sent	\N	2026-08-01 04:23:01.413533+00
c565046f-a41a-48dc-a2e3-f53f0389fd77	15c14766-aa02-4e61-be85-41b79c3ffe85	254740258495	bonte: 1 Hour activated.\nUsername: B1\nPassword: c5ye9c\nExpires: 01 Aug 2026, 10:05\nReceipt: UH11314F3A	rumalink	\N	sent	\N	2026-08-01 06:06:00.474569+00
e452f134-2869-4516-9ccb-c0f654400e44	15c14766-aa02-4e61-be85-41b79c3ffe85	254117195942	bonte: 1 Hour activated.\nUsername: B31\nPassword: y9fce4\nExpires: 01 Aug 2026, 10:19\nReceipt: UH1C811RP5	rumalink	\N	sent	\N	2026-08-01 06:19:20.245427+00
5c7e39fd-b205-4e38-b159-104e783e9b80	15c14766-aa02-4e61-be85-41b79c3ffe85	254740258495	bonte: 1 Hour activated for Gytv.\nIt connects automatically — no login needed.\nExpires: 01 Aug 2026, 10:42\nReceipt: UH11314QE7	rumalink	\N	sent	\N	2026-08-01 06:42:52.995329+00
2e87cd49-3c78-4ba5-acab-96c76b126665	15c14766-aa02-4e61-be85-41b79c3ffe85	254704994652	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 11:15, 01 Aug. You'll get another SMS when service is restored.	rumalink	\N	sent	\N	2026-08-01 11:15:20.389838+00
f1273ea5-be7e-4069-b4cc-2985c2b02a63	15c14766-aa02-4e61-be85-41b79c3ffe85	254704994652	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 11:17, 01 Aug. Outage lasted 1m.	rumalink	\N	sent	\N	2026-08-01 11:17:04.430888+00
\.


--
-- Data for Name: sms_provider_config; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_provider_config (id, provider, api_key, sender_id, base_url, is_active, updated_at) FROM stdin;
1	talksasa	1109|mgZZ8Ybp3dVmuZyqraO5gKV4vx8ULnFoQwQod4Oua56532b7	TALKSASA	https://bulksms.talksasa.com/api/v3	t	2026-06-27 09:11:01.50878+00
\.


--
-- Data for Name: support_replies; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.support_replies (id, ticket_id, author_type, author_id, message, created_at) FROM stdin;
\.


--
-- Data for Name: support_tickets; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.support_tickets (id, isp_id, subject, message, status, priority, assigned_to, resolved_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: system_health; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_health (id, sampled_at, load1, cpu_steal, mem_total_mb, mem_avail_mb, swap_used_mb, disk_pct, freeradius_mb, node_mb, pg_conns, routers_total, routers_down, status) FROM stdin;
1	2026-07-31 09:06:42.342017+00	0.35	0	1906	1363	0	20	56	97	15	1	0	ok
2	2026-07-31 09:07:42.339772+00	0.13	0	1906	1336	0	20	56	91	13	1	0	ok
3	2026-07-31 09:08:10.511475+00	0.45	0	1906	1362	0	20	56	99	15	1	0	ok
4	2026-07-31 09:09:10.508802+00	0.61	0.5	1906	1328	0	20	56	94	16	1	0	ok
5	2026-07-31 09:10:10.509951+00	0.66	0	1906	1324	0	20	56	96	16	1	0	ok
6	2026-07-31 09:11:10.509965+00	0.68	0	1906	1322	0	20	56	98	16	1	0	ok
7	2026-07-31 09:12:10.510309+00	0.32	0.5	1906	1322	0	20	56	101	14	1	0	ok
8	2026-07-31 09:12:37.82225+00	0.28	0	1906	1366	0	20	56	98	15	1	0	ok
9	2026-07-31 09:13:37.820852+00	0.41	0	1906	1350	0	20	56	86	14	1	0	ok
10	2026-07-31 09:14:37.82277+00	0.37	0	1906	1332	0	20	56	94	14	1	0	ok
11	2026-07-31 09:15:37.822235+00	0.49	0	1906	1338	0	20	56	96	15	1	0	ok
12	2026-07-31 09:16:37.82258+00	0.18	0	1906	1331	0	20	56	99	14	1	0	ok
13	2026-07-31 09:17:37.823685+00	0.29	0	1906	1329	0	20	56	95	15	1	0	ok
14	2026-07-31 09:18:37.825006+00	0.42	0	1906	1323	0	20	56	98	15	1	0	ok
15	2026-07-31 09:19:37.825289+00	0.37	0	1906	1326	0	20	56	100	13	1	0	ok
16	2026-07-31 09:20:37.826445+00	0.4	0	1906	1331	0	20	56	101	14	1	0	ok
17	2026-07-31 09:21:37.826756+00	0.4	0	1906	1322	0	20	56	101	13	1	0	ok
18	2026-07-31 09:22:37.826507+00	0.28	0.5	1906	1319	0	20	56	101	13	1	0	ok
19	2026-07-31 09:23:37.828068+00	0.1	0	1906	1308	0	20	56	102	12	1	0	ok
20	2026-07-31 09:24:37.8277+00	0.3	0	1906	1312	0	20	56	102	13	1	0	ok
21	2026-07-31 09:25:37.826858+00	0.47	0	1906	1315	0	20	56	102	13	1	0	ok
22	2026-07-31 09:26:37.830309+00	0.17	0	1906	1335	0	20	56	103	15	1	0	ok
23	2026-07-31 09:27:37.831331+00	0.2	0	1906	1325	0	20	56	103	13	1	0	ok
24	2026-07-31 09:28:37.833626+00	0.34	0	1906	1323	0	20	56	105	13	1	0	ok
25	2026-07-31 09:29:37.829525+00	0.39	0	1906	1320	0	20	56	106	13	1	0	ok
26	2026-07-31 09:30:37.829644+00	0.44	0	1906	1312	0	20	56	105	13	1	0	ok
27	2026-07-31 09:31:37.83215+00	0.16	0	1906	1316	0	20	56	106	13	1	0	ok
28	2026-07-31 09:32:37.831522+00	0.41	0	1906	1329	0	20	56	107	13	1	0	ok
29	2026-07-31 09:33:37.832485+00	0.42	0	1906	1332	0	20	56	107	13	1	0	ok
30	2026-07-31 09:34:37.830862+00	0.29	0	1906	1319	0	20	56	106	13	1	0	ok
31	2026-07-31 09:35:37.832707+00	0.1	0	1906	1310	0	20	56	107	13	1	0	ok
32	2026-07-31 09:36:37.836493+00	0.21	0	1906	1323	0	20	56	101	13	1	0	ok
33	2026-07-31 09:37:37.83475+00	0.3	0	1906	1318	0	20	56	104	13	1	0	ok
34	2026-07-31 09:38:37.833583+00	0.24	0	1906	1314	0	20	56	107	14	1	0	ok
35	2026-07-31 09:39:37.833677+00	0.09	0.5	1906	1326	0	20	56	107	13	1	0	ok
36	2026-07-31 09:40:37.833645+00	0.34	0	1906	1320	0	20	56	107	13	1	0	ok
37	2026-07-31 09:41:37.833435+00	0.39	0	1906	1319	0	20	56	107	13	1	0	ok
38	2026-07-31 09:42:37.834551+00	0.41	0	1906	1318	0	20	56	108	13	1	0	ok
39	2026-07-31 09:43:37.834637+00	0.37	0	1906	1316	0	20	56	108	13	1	0	ok
40	2026-07-31 09:44:37.833565+00	0.13	0	1906	1308	0	20	56	109	13	1	0	ok
41	2026-07-31 09:45:37.837752+00	0.05	0	1906	1319	0	20	56	109	14	1	0	ok
42	2026-07-31 09:46:37.835773+00	0.24	0	1906	1310	0	20	56	109	13	1	0	ok
43	2026-07-31 09:47:37.835749+00	0.26	0	1906	1313	0	20	56	109	13	1	0	ok
44	2026-07-31 09:48:37.837302+00	0.32	0	1906	1311	0	20	56	111	14	1	0	ok
45	2026-07-31 09:49:37.836528+00	0.28	0	1906	1304	0	20	56	111	13	1	0	ok
46	2026-07-31 09:50:37.834777+00	0.24	0	1906	1308	0	20	56	111	13	1	0	ok
47	2026-07-31 09:51:38.900931+00	0.17	0	1906	1318	0	20	56	111	13	1	1	warning
48	2026-07-31 09:52:37.835895+00	0.15	0	1906	1306	0	20	56	111	14	1	1	warning
49	2026-07-31 09:53:37.835099+00	0.28	0	1906	1308	0	20	56	111	13	1	1	warning
50	2026-07-31 09:54:37.836818+00	0.14	0	1906	1309	0	20	56	111	14	1	1	warning
51	2026-07-31 09:55:37.83634+00	0.05	0	1906	1316	0	20	56	111	13	1	1	warning
52	2026-07-31 09:56:37.840087+00	0.11	0	1906	1320	0	20	56	111	14	1	1	warning
53	2026-07-31 09:57:37.841151+00	0.04	0	1906	1306	0	20	56	111	14	1	1	warning
54	2026-07-31 09:58:37.839638+00	0.01	0	1906	1305	0	20	56	111	15	1	1	warning
55	2026-07-31 09:59:38.897671+00	0.27	0	1906	1312	0	20	56	111	12	1	0	ok
56	2026-07-31 10:00:37.84139+00	0.37	0	1906	1313	0	20	56	112	12	1	0	ok
57	2026-07-31 10:01:37.842858+00	0.18	0	1906	1322	0	20	56	111	11	1	0	ok
58	2026-07-31 10:02:37.841845+00	0.06	0	1906	1315	0	20	56	112	12	1	0	ok
59	2026-07-31 10:03:37.842157+00	0.02	0	1906	1310	0	20	56	112	11	1	0	ok
60	2026-07-31 10:04:37.84318+00	0.14	0	1906	1310	0	20	56	112	12	1	0	ok
61	2026-07-31 10:05:37.841615+00	0.14	0	1906	1314	0	20	56	112	12	1	0	ok
62	2026-07-31 10:06:37.843246+00	0.27	0	1906	1310	0	20	56	112	12	1	0	ok
63	2026-07-31 10:07:37.842959+00	0.19	0	1906	1316	0	20	56	112	12	1	0	ok
64	2026-07-31 10:08:37.842428+00	0.07	0	1906	1304	0	20	56	113	11	1	0	ok
65	2026-07-31 10:09:37.844406+00	0.02	0	1906	1305	0	20	56	112	11	1	0	ok
66	2026-07-31 10:10:37.84464+00	0.01	0	1906	1315	0	20	56	113	12	1	0	ok
67	2026-07-31 10:11:37.843046+00	0.07	0	1906	1312	0	20	56	112	10	1	0	ok
68	2026-07-31 10:12:37.841803+00	0.16	0	1906	1309	0	20	56	112	12	1	0	ok
69	2026-07-31 10:13:37.842824+00	0.15	0	1906	1316	0	20	56	112	12	1	0	ok
70	2026-07-31 10:14:37.843071+00	0.14	0	1906	1316	0	20	56	112	13	1	0	ok
71	2026-07-31 10:15:37.845513+00	0.14	0.5	1906	1321	0	20	56	113	12	1	0	ok
72	2026-07-31 10:16:37.843662+00	0.11	0	1906	1312	0	20	56	112	12	1	0	ok
73	2026-07-31 10:17:37.844875+00	0.04	0	1906	1310	0	20	56	113	10	1	0	ok
74	2026-07-31 10:18:37.844642+00	0.17	0	1906	1304	0	20	56	113	11	1	0	ok
75	2026-07-31 10:19:37.844616+00	0.09	0	1906	1316	0	20	56	112	11	1	0	ok
76	2026-07-31 10:20:37.845752+00	0.32	0	1906	1303	0	20	56	113	11	1	0	ok
77	2026-07-31 10:21:37.846631+00	0.12	0.5	1906	1313	0	20	56	112	10	1	0	ok
78	2026-07-31 10:22:37.84726+00	0.04	0	1906	1302	0	20	56	113	10	1	0	ok
79	2026-07-31 10:23:37.845516+00	0.01	0	1906	1319	0	20	56	112	10	1	0	ok
80	2026-07-31 10:24:37.847106+00	0	0	1906	1309	0	20	56	113	10	1	0	ok
81	2026-07-31 10:25:37.84615+00	0	0	1906	1312	0	20	56	112	10	1	0	ok
82	2026-07-31 10:26:37.845201+00	0	0	1906	1313	0	20	56	113	11	1	0	ok
83	2026-07-31 10:27:37.847063+00	0	0	1906	1312	0	20	56	112	11	1	0	ok
84	2026-07-31 10:28:37.846955+00	0	0	1906	1299	0	20	56	113	12	1	0	ok
85	2026-07-31 10:29:37.845221+00	0	0	1906	1300	0	20	56	113	10	0	0	ok
86	2026-07-31 10:30:37.846698+00	0	0	1906	1298	0	20	56	113	10	0	0	ok
87	2026-07-31 10:31:37.846935+00	0	0	1906	1308	0	20	56	113	10	0	0	ok
88	2026-07-31 10:32:37.847896+00	0.03	0	1906	1296	0	20	56	113	10	0	0	ok
89	2026-07-31 10:33:37.849+00	0.11	0	1906	1317	0	20	56	113	11	0	0	ok
90	2026-07-31 10:34:37.84832+00	0.07	0	1906	1308	0	20	56	114	10	0	0	ok
91	2026-07-31 10:35:37.849596+00	0.14	0	1906	1302	0	20	56	114	11	0	0	ok
92	2026-07-31 10:36:37.848506+00	0.05	0	1906	1295	0	20	56	114	11	0	0	ok
93	2026-07-31 10:37:37.847856+00	0.02	0	1906	1291	0	20	56	113	11	0	0	ok
94	2026-07-31 10:38:37.850087+00	0	0	1906	1305	0	20	56	114	11	0	0	ok
95	2026-07-31 10:39:37.849751+00	0	0	1906	1299	0	20	56	113	11	0	0	ok
96	2026-07-31 10:40:37.84918+00	0	0	1906	1292	0	20	56	114	11	0	0	ok
97	2026-07-31 10:41:37.850845+00	0	0	1906	1301	0	20	56	114	12	0	0	ok
98	2026-07-31 10:42:37.851104+00	0.05	0	1906	1299	0	20	56	114	11	0	0	ok
99	2026-07-31 10:43:37.852153+00	0.02	0	1906	1290	0	20	56	115	11	0	0	ok
100	2026-07-31 10:44:37.853333+00	0	0	1906	1298	0	20	56	116	11	0	0	ok
101	2026-07-31 10:45:37.853419+00	0	0	1906	1306	0	20	56	115	11	0	0	ok
102	2026-07-31 10:46:37.852739+00	0	0	1906	1307	0	20	56	115	12	0	0	ok
103	2026-07-31 10:47:37.854358+00	0	0	1906	1298	0	20	56	116	12	0	0	ok
104	2026-07-31 10:48:37.854962+00	0	0	1906	1291	0	20	56	115	11	0	0	ok
105	2026-07-31 10:49:37.853998+00	0	0	1906	1287	0	20	56	115	14	0	0	ok
106	2026-07-31 10:50:37.85274+00	0	0	1906	1308	0	20	56	116	11	0	0	ok
107	2026-07-31 10:51:37.856232+00	0	0	1906	1304	0	20	56	116	11	0	0	ok
108	2026-07-31 10:52:37.855367+00	0	0	1906	1295	0	20	57	115	11	1	0	ok
109	2026-07-31 10:53:37.856262+00	0	0	1906	1306	0	20	57	115	11	1	0	ok
110	2026-07-31 10:54:37.85499+00	0	0.5	1906	1297	0	20	57	116	11	1	0	ok
111	2026-07-31 10:55:37.856577+00	0.05	0	1906	1305	0	20	57	108	12	1	0	ok
112	2026-07-31 10:56:37.859281+00	0.02	0	1906	1293	0	20	57	114	12	1	0	ok
113	2026-07-31 10:57:37.864254+00	0	0	1906	1305	0	20	57	114	11	1	0	ok
114	2026-07-31 10:58:37.863823+00	0.06	0	1906	1282	0	20	57	115	17	1	0	ok
115	2026-07-31 10:59:37.86345+00	0.02	0	1906	1296	0	20	57	115	11	1	0	ok
116	2026-07-31 11:00:37.861802+00	0.09	0	1906	1292	0	20	57	115	12	1	0	ok
117	2026-07-31 11:01:37.862815+00	0.03	0	1906	1306	0	20	57	115	12	1	0	ok
118	2026-07-31 11:02:37.864991+00	0.01	0	1906	1291	0	20	57	115	13	1	0	ok
119	2026-07-31 11:03:37.86304+00	0	0	1906	1292	0	20	57	115	12	1	0	ok
120	2026-07-31 11:04:37.863177+00	0	0	1906	1298	0	20	57	116	12	1	0	ok
121	2026-07-31 11:05:37.864066+00	0	0.5	1906	1303	0	20	57	115	12	1	0	ok
122	2026-07-31 11:06:37.864606+00	0	0	1906	1297	0	20	57	118	14	1	0	ok
123	2026-07-31 11:07:37.864955+00	0	0	1906	1303	0	20	57	116	12	1	0	ok
124	2026-07-31 11:08:37.866779+00	0	0	1906	1291	0	20	57	116	12	1	0	ok
125	2026-07-31 11:09:37.864995+00	0	0	1906	1304	0	20	57	116	11	1	0	ok
126	2026-07-31 11:10:37.868072+00	0.25	0	1906	1288	0	20	57	116	12	1	0	ok
127	2026-07-31 11:11:37.868407+00	0.09	0	1906	1295	0	20	57	116	15	1	0	ok
128	2026-07-31 11:12:37.867431+00	0.03	0	1906	1289	0	20	57	122	11	1	0	ok
129	2026-07-31 11:13:37.869188+00	0.01	0	1906	1293	0	20	57	122	11	1	0	ok
130	2026-07-31 11:14:37.86998+00	0.09	0	1906	1294	0	20	57	122	11	1	0	ok
131	2026-07-31 11:15:37.870899+00	0.03	0	1906	1291	0	20	57	123	12	1	0	ok
132	2026-07-31 11:16:37.870852+00	0.01	0	1906	1296	0	20	57	122	12	1	0	ok
133	2026-07-31 11:17:37.871548+00	0	0	1906	1304	0	20	57	122	11	1	0	ok
134	2026-07-31 11:18:37.870685+00	0	0	1906	1290	0	20	57	123	12	1	0	ok
135	2026-07-31 11:19:37.87289+00	0.24	0	1906	1295	0	20	57	123	11	1	0	ok
136	2026-07-31 11:20:37.869537+00	0.09	0	1906	1294	0	20	57	122	12	1	0	ok
137	2026-07-31 11:21:37.870958+00	0.03	0	1906	1295	0	20	57	123	11	1	0	ok
138	2026-07-31 11:22:37.870877+00	0.01	0	1906	1286	0	20	57	124	11	1	0	ok
139	2026-07-31 11:23:37.874958+00	0	0	1906	1290	0	20	57	124	12	1	0	ok
140	2026-07-31 11:24:37.870887+00	0	0	1906	1293	0	20	57	123	12	1	0	ok
141	2026-07-31 11:25:37.870309+00	0	0	1906	1297	0	20	57	123	12	1	0	ok
142	2026-07-31 11:26:37.871288+00	0	0	1906	1284	0	20	57	124	11	1	0	ok
143	2026-07-31 11:27:37.872964+00	0	0	1906	1299	0	20	57	124	11	1	0	ok
144	2026-07-31 11:28:37.87158+00	0	0	1906	1285	0	20	57	123	11	1	0	ok
145	2026-07-31 11:29:37.873678+00	0	0	1906	1301	0	20	57	124	10	1	0	ok
146	2026-07-31 11:30:37.872715+00	0	0	1906	1294	0	20	57	123	10	1	0	ok
147	2026-07-31 11:31:37.873913+00	0	0	1906	1292	0	20	57	123	10	1	0	ok
148	2026-07-31 11:32:37.87333+00	0.14	0	1906	1289	0	20	57	124	10	1	0	ok
149	2026-07-31 11:33:37.874623+00	0.13	0	1906	1294	0	20	57	123	10	1	0	ok
150	2026-07-31 11:34:15.396266+00	0.15	0.5	1906	1349	0	20	57	99	12	1	0	ok
151	2026-07-31 11:35:15.397868+00	0.22	0	1906	1306	0	20	57	102	15	1	0	ok
152	2026-07-31 11:36:15.397709+00	0.08	0	1906	1303	0	20	57	105	15	1	0	ok
153	2026-07-31 11:37:15.399952+00	0.03	0.5	1906	1297	0	20	57	107	14	1	0	ok
154	2026-07-31 11:38:15.39984+00	0.01	0.49	1906	1298	0	20	57	108	19	1	0	ok
155	2026-07-31 11:39:15.400544+00	0	0	1906	1299	0	20	57	108	18	1	0	ok
156	2026-07-31 11:40:15.401029+00	0	0	1906	1289	0	20	57	109	19	1	0	ok
157	2026-07-31 11:41:15.404201+00	0	0	1906	1302	0	20	57	109	17	1	0	ok
158	2026-07-31 11:42:15.401715+00	0	0	1906	1297	0	20	57	109	16	1	0	ok
159	2026-07-31 11:43:15.401153+00	0	0.5	1906	1296	0	20	57	109	16	1	0	ok
160	2026-07-31 11:44:15.400903+00	0	0	1906	1284	0	20	57	109	19	1	0	ok
161	2026-07-31 11:45:15.400539+00	0.06	0	1906	1290	0	20	57	109	18	1	0	ok
162	2026-07-31 11:46:15.401584+00	0.02	0	1906	1291	0	20	57	109	19	1	0	ok
163	2026-07-31 11:47:15.402179+00	0	0	1906	1292	0	20	57	102	18	1	0	ok
164	2026-07-31 11:48:15.40335+00	0	0.5	1906	1298	0	20	57	104	18	1	0	ok
165	2026-07-31 11:49:15.400566+00	0	0	1906	1297	0	20	57	107	18	1	0	ok
166	2026-07-31 11:50:15.40372+00	0.11	0	1906	1292	0	20	57	110	18	1	0	ok
167	2026-07-31 11:51:15.402962+00	0.04	0	1906	1307	0	20	57	110	15	1	0	ok
168	2026-07-31 11:52:15.403218+00	0.01	0.5	1906	1298	0	20	57	109	18	1	0	ok
169	2026-07-31 11:53:15.402766+00	0	0.5	1906	1294	0	20	57	110	18	1	0	ok
170	2026-07-31 11:53:56.940804+00	0	0	1906	1356	0	20	57	98	12	1	0	ok
171	2026-07-31 11:54:56.940934+00	0	0	1906	1335	0	20	57	94	10	1	0	ok
172	2026-07-31 11:55:56.939889+00	0	0	1906	1330	0	20	57	96	10	1	0	ok
173	2026-07-31 11:56:56.938193+00	0	0	1906	1303	0	20	57	96	10	1	0	ok
174	2026-07-31 11:57:56.940138+00	0	0	1906	1327	0	20	57	98	10	1	0	ok
175	2026-07-31 11:58:56.942519+00	0.03	0	1906	1323	0	20	57	101	11	1	0	ok
176	2026-07-31 11:59:56.942929+00	0.01	0	1906	1334	0	20	57	94	12	1	0	ok
177	2026-07-31 12:00:56.941611+00	0	0	1906	1329	0	20	57	97	10	1	0	ok
178	2026-07-31 12:01:56.940342+00	0	0.5	1906	1330	0	20	57	100	11	1	0	ok
179	2026-07-31 12:02:56.942827+00	0	0	1906	1326	0	20	57	101	11	1	0	ok
180	2026-07-31 12:03:56.946238+00	0	0	1906	1324	0	20	57	102	14	1	0	ok
181	2026-07-31 12:04:56.94513+00	0.03	0	1906	1313	0	20	56	101	12	1	0	ok
182	2026-07-31 12:05:56.946701+00	0.05	0	1906	1316	0	20	56	101	13	1	0	ok
183	2026-07-31 12:06:56.945047+00	0.02	0	1906	1326	0	20	56	102	9	1	0	ok
184	2026-07-31 12:07:56.944605+00	0	0	1906	1315	0	20	56	103	9	1	0	ok
185	2026-07-31 12:08:56.945276+00	0	0	1906	1327	0	20	56	102	10	1	0	ok
186	2026-07-31 12:09:56.946824+00	0	0	1906	1324	0	20	56	103	11	1	0	ok
187	2026-07-31 12:10:56.945314+00	0.04	0	1906	1321	0	20	56	103	13	1	0	ok
188	2026-07-31 12:11:56.945983+00	0.01	0	1906	1320	0	20	56	104	14	1	0	ok
189	2026-07-31 12:12:56.948256+00	0	0	1906	1317	0	20	56	105	10	1	0	ok
190	2026-07-31 12:13:56.947316+00	0	0	1906	1319	0	20	56	106	10	1	0	ok
191	2026-07-31 12:14:20.257674+00	0.08	0	1906	1360	0	20	56	98	12	1	0	ok
192	2026-07-31 12:15:20.255268+00	0.03	0	1906	1323	0	20	56	87	16	1	0	ok
193	2026-07-31 12:16:20.259279+00	0.01	0	1906	1309	0	20	56	97	17	1	0	ok
194	2026-07-31 12:17:20.260108+00	0	0	1906	1294	0	20	56	97	16	1	0	ok
195	2026-07-31 12:17:34.367723+00	0	0.5	1906	1354	0	20	56	99	14	1	0	ok
196	2026-07-31 12:18:34.36825+00	0	0	1906	1317	0	20	56	99	12	1	0	ok
197	2026-07-31 12:19:34.369913+00	0	0	1906	1316	0	20	56	101	12	1	0	ok
198	2026-07-31 12:20:34.368219+00	0	0	1906	1313	0	20	56	104	12	1	0	ok
199	2026-07-31 12:21:34.36983+00	0.06	0	1906	1303	0	20	56	106	12	1	0	ok
200	2026-07-31 12:22:34.369316+00	0.02	0	1906	1317	0	20	56	101	12	1	0	ok
201	2026-07-31 12:23:29.786497+00	0.01	0	1906	1340	0	20	56	99	14	1	0	ok
202	2026-07-31 12:24:29.786096+00	0	0	1906	1311	0	20	56	91	21	1	0	ok
203	2026-07-31 12:25:29.787157+00	0	0	1906	1320	0	20	56	95	15	1	0	ok
204	2026-07-31 12:26:29.787194+00	0.04	0	1906	1307	0	20	56	96	19	1	0	ok
205	2026-07-31 12:27:29.786599+00	0.01	0	1906	1314	0	20	56	99	13	1	0	ok
206	2026-07-31 12:28:29.787636+00	0	0	1906	1314	0	20	56	101	17	1	0	ok
207	2026-07-31 12:29:29.78809+00	0	0	1906	1317	0	20	56	95	16	1	0	ok
208	2026-07-31 12:30:29.789098+00	0	0	1906	1312	0	20	56	97	17	1	0	ok
209	2026-07-31 12:31:29.788263+00	0.08	0	1906	1307	0	20	56	100	17	1	0	ok
210	2026-07-31 12:32:29.790249+00	0.19	0	1906	1302	0	20	56	102	17	1	0	ok
211	2026-07-31 12:33:29.791011+00	0.11	0	1906	1305	0	20	56	102	17	1	0	ok
212	2026-07-31 12:34:29.792787+00	0.04	0.5	1906	1306	0	20	56	101	17	1	0	ok
213	2026-07-31 12:35:29.791311+00	0.06	0	1906	1302	0	20	56	105	16	1	0	ok
214	2026-07-31 12:36:29.791308+00	0.02	0	1906	1292	0	20	56	106	16	1	0	ok
215	2026-07-31 12:37:29.792298+00	0	0	1906	1297	0	20	56	106	16	1	0	ok
216	2026-07-31 12:38:29.791945+00	0.04	0	1906	1306	0	20	56	106	14	1	0	ok
217	2026-07-31 12:39:29.792178+00	0.01	0	1906	1297	0	20	56	106	14	1	0	ok
218	2026-07-31 12:40:29.79096+00	0	0	1906	1311	0	20	56	106	15	1	0	ok
219	2026-07-31 12:41:29.790496+00	0	0	1906	1307	0	20	56	107	16	1	0	ok
220	2026-07-31 12:42:29.790883+00	0	0	1906	1309	0	20	56	108	16	1	0	ok
221	2026-07-31 12:43:29.791125+00	0	0	1906	1301	0	20	56	107	16	1	0	ok
222	2026-07-31 12:44:29.790487+00	0	0	1906	1303	0	20	56	107	16	1	0	ok
223	2026-07-31 12:45:29.792969+00	0	0	1906	1307	0	20	56	100	16	1	0	ok
224	2026-07-31 12:46:29.795236+00	0	0	1906	1315	0	20	56	102	16	1	0	ok
225	2026-07-31 12:47:29.793636+00	0.08	0	1906	1307	0	20	56	105	16	1	0	ok
226	2026-07-31 12:48:29.793846+00	0.03	0	1906	1313	0	20	56	107	13	1	0	ok
227	2026-07-31 12:49:29.794383+00	0.01	0	1906	1306	0	20	56	108	13	1	0	ok
228	2026-07-31 12:50:29.797313+00	0	0	1906	1313	0	20	56	107	13	1	0	ok
229	2026-07-31 12:51:29.793441+00	0	0	1906	1300	0	20	56	107	13	1	0	ok
230	2026-07-31 12:52:29.793939+00	0	0	1906	1302	0	20	56	107	13	1	0	ok
231	2026-07-31 12:53:29.803701+00	0.23	0	1906	1256	0	20	56	109	13	1	0	ok
232	2026-07-31 12:54:29.794315+00	0.08	0	1906	1292	0	20	56	107	13	1	0	ok
233	2026-07-31 12:55:29.795142+00	0.03	0	1906	1298	0	20	56	108	12	1	0	ok
234	2026-07-31 12:56:29.794837+00	0.01	0	1906	1296	0	20	56	109	12	1	0	ok
235	2026-07-31 12:57:29.796282+00	0	0	1906	1292	0	20	56	117	13	1	0	ok
236	2026-07-31 12:58:29.796437+00	0	0	1906	1292	0	20	56	117	12	1	0	ok
237	2026-07-31 12:59:29.796908+00	0	0	1906	1295	0	20	56	117	13	1	0	ok
238	2026-07-31 13:00:29.79634+00	0	0	1906	1306	0	20	56	117	14	1	0	ok
239	2026-07-31 13:01:29.795461+00	0	0	1906	1296	0	20	56	117	16	1	0	ok
240	2026-07-31 13:02:29.797442+00	0	0	1906	1286	0	20	56	118	17	1	0	ok
241	2026-07-31 13:03:29.797758+00	0	0	1906	1297	0	20	56	118	17	1	0	ok
242	2026-07-31 13:04:29.800052+00	0	0	1906	1295	0	20	56	118	17	1	0	ok
243	2026-07-31 13:05:29.799299+00	0	0	1906	1298	0	20	56	119	17	1	0	ok
244	2026-07-31 13:06:29.800925+00	0	0	1906	1295	0	20	56	118	18	1	0	ok
245	2026-07-31 13:07:29.799698+00	0	0	1906	1289	0	20	56	118	18	1	0	ok
246	2026-07-31 13:08:29.799004+00	0	0	1906	1294	0	20	56	120	17	1	0	ok
247	2026-07-31 13:09:29.800066+00	0.06	0	1906	1295	0	20	57	119	17	1	0	ok
248	2026-07-31 13:10:29.800619+00	0.02	0	1906	1291	0	20	57	118	17	1	0	ok
249	2026-07-31 13:11:29.802111+00	0.01	0	1906	1297	0	20	57	118	17	1	0	ok
250	2026-07-31 13:12:29.804547+00	0	0	1906	1299	0	20	57	119	17	1	0	ok
251	2026-07-31 13:13:29.804142+00	0	0	1906	1279	0	20	57	118	18	1	0	ok
252	2026-07-31 13:14:29.803711+00	0	0	1906	1297	0	20	57	118	13	1	0	ok
253	2026-07-31 13:15:29.80466+00	0	0	1906	1290	0	20	57	119	14	1	0	ok
254	2026-07-31 13:16:29.806111+00	0.03	0	1906	1299	0	20	57	120	13	1	0	ok
255	2026-07-31 13:17:29.807297+00	0.04	0	1906	1302	0	20	57	119	13	1	0	ok
256	2026-07-31 13:18:29.807232+00	0.01	0	1906	1297	0	20	57	119	13	1	0	ok
257	2026-07-31 13:19:29.807877+00	0	0	1906	1290	0	20	57	119	15	1	0	ok
258	2026-07-31 13:20:29.806967+00	0	0	1906	1297	0	20	57	121	15	1	0	ok
259	2026-07-31 13:21:29.808272+00	0	0	1906	1300	0	20	57	119	15	1	0	ok
260	2026-07-31 13:22:29.809436+00	0	0	1906	1294	0	20	57	120	18	1	0	ok
261	2026-07-31 13:23:29.810286+00	0	0	1906	1280	0	20	57	120	17	1	0	ok
262	2026-07-31 13:24:29.812895+00	0.03	0	1906	1287	0	20	57	120	18	1	0	ok
263	2026-07-31 13:25:29.813057+00	0.07	0	1906	1291	0	20	57	120	17	1	0	ok
264	2026-07-31 13:26:29.812456+00	0.02	0	1906	1288	0	20	57	121	17	1	0	ok
265	2026-07-31 13:27:29.81262+00	0.01	0	1906	1278	0	20	57	120	18	1	0	ok
266	2026-07-31 13:28:29.814513+00	0	0	1906	1292	0	20	57	122	17	1	0	ok
267	2026-07-31 13:29:29.823247+00	0	0	1906	1292	0	20	57	121	18	1	0	ok
268	2026-07-31 13:30:29.817305+00	0	0	1906	1297	0	20	57	121	17	1	0	ok
269	2026-07-31 13:31:29.820272+00	0	0	1906	1290	0	20	57	121	17	1	0	ok
270	2026-07-31 13:32:29.81997+00	0	0	1906	1292	0	20	57	121	17	1	0	ok
271	2026-07-31 13:33:29.819279+00	0	0	1906	1290	0	20	57	121	17	1	0	ok
272	2026-07-31 13:34:29.821087+00	0	0	1906	1304	0	20	57	115	17	1	0	ok
273	2026-07-31 13:35:29.820161+00	0.07	0	1906	1300	0	20	57	117	17	1	0	ok
274	2026-07-31 13:36:29.819524+00	0.08	0	1906	1293	0	20	57	119	17	1	0	ok
275	2026-07-31 13:37:29.820575+00	0.03	0	1906	1283	0	20	57	120	17	1	0	ok
276	2026-07-31 13:38:29.819811+00	0.01	0	1906	1287	0	20	57	121	17	1	0	ok
277	2026-07-31 13:39:29.823222+00	0.04	0	1906	1299	0	20	57	120	17	1	0	ok
278	2026-07-31 13:40:29.824109+00	0.01	0	1906	1289	0	20	57	120	17	1	0	ok
279	2026-07-31 13:41:29.824876+00	0	0	1906	1290	0	20	57	121	17	1	0	ok
280	2026-07-31 13:42:29.828307+00	0	0	1906	1300	0	20	57	121	16	1	0	ok
281	2026-07-31 13:43:29.826863+00	0	0	1906	1293	0	20	57	121	17	1	0	ok
282	2026-07-31 13:44:29.825541+00	0	0	1906	1291	0	20	57	120	16	1	0	ok
283	2026-07-31 13:45:29.827578+00	0	0	1906	1297	0	20	57	120	17	1	0	ok
284	2026-07-31 13:46:29.827048+00	0.53	0	1906	1283	0	20	57	120	17	1	0	ok
285	2026-07-31 13:47:29.830522+00	0.22	0	1906	1292	0	20	57	120	17	1	0	ok
286	2026-07-31 13:48:29.833122+00	0.61	0	1906	1293	0	20	57	121	19	1	0	ok
287	2026-07-31 13:49:29.834257+00	0.43	0	1906	1287	0	20	57	121	18	1	0	ok
288	2026-07-31 13:50:29.831895+00	0.84	0	1906	1289	0	20	57	122	19	1	0	ok
289	2026-07-31 13:51:29.83275+00	0.31	0	1906	1288	0	20	57	121	18	1	0	ok
290	2026-07-31 13:52:29.833275+00	0.19	0	1906	1284	0	20	57	121	19	1	0	ok
291	2026-07-31 13:53:29.833728+00	0.07	0	1906	1287	0	20	57	121	17	1	0	ok
292	2026-07-31 13:54:29.833658+00	0.02	0	1906	1291	0	20	57	121	17	1	0	ok
293	2026-07-31 13:55:29.833773+00	0.01	0	1906	1294	0	20	57	121	16	1	0	ok
294	2026-07-31 13:56:29.833868+00	0	0	1906	1294	0	20	57	120	18	1	0	ok
295	2026-07-31 13:57:29.832568+00	0.04	0	1906	1296	0	20	57	120	15	1	0	ok
296	2026-07-31 13:58:29.834606+00	0.01	0	1906	1286	0	20	57	120	16	1	0	ok
297	2026-07-31 13:59:29.834953+00	0	0	1906	1291	0	20	57	121	17	1	0	ok
298	2026-07-31 14:00:29.836189+00	0	0	1906	1287	0	20	57	120	18	1	0	ok
299	2026-07-31 14:01:29.836596+00	0	0	1906	1285	0	20	57	120	17	1	0	ok
300	2026-07-31 14:02:29.835135+00	0.05	0	1906	1299	0	20	57	120	16	1	0	ok
301	2026-07-31 14:03:29.833987+00	0.07	0	1906	1295	0	20	57	120	11	1	0	ok
302	2026-07-31 14:04:29.835528+00	0.02	0	1906	1290	0	20	57	121	15	1	0	ok
303	2026-07-31 14:05:29.834927+00	0.01	0	1906	1297	0	20	57	121	16	1	0	ok
304	2026-07-31 14:06:29.835455+00	0	0	1906	1295	0	20	57	121	17	1	0	ok
305	2026-07-31 14:07:29.836715+00	0	0	1906	1282	0	20	57	121	17	1	0	ok
306	2026-07-31 14:08:29.835463+00	0	0	1906	1294	0	20	57	120	18	1	0	ok
307	2026-07-31 14:09:29.835008+00	0	0	1906	1284	0	20	57	120	18	1	0	ok
308	2026-07-31 14:10:29.837556+00	0	0	1906	1289	0	20	57	120	17	1	0	ok
309	2026-07-31 14:11:29.836256+00	0	0	1906	1292	0	20	57	121	18	1	0	ok
310	2026-07-31 14:12:29.837792+00	0	0	1906	1281	0	20	57	121	19	1	0	ok
311	2026-07-31 14:13:29.83585+00	0	0	1906	1297	0	20	57	121	16	1	0	ok
312	2026-07-31 14:14:29.836441+00	0	0	1906	1293	0	20	57	120	18	1	0	ok
313	2026-07-31 14:15:29.839866+00	0	0	1906	1302	0	20	57	120	14	1	0	ok
314	2026-07-31 14:16:29.837144+00	0	0	1906	1289	0	20	57	120	16	1	0	ok
315	2026-07-31 14:17:29.837138+00	0	0	1906	1293	0	20	57	121	18	1	0	ok
316	2026-07-31 14:18:29.837366+00	0	0	1906	1292	0	20	57	121	18	1	0	ok
317	2026-07-31 14:19:29.837818+00	0	0	1906	1289	0	20	57	121	17	1	0	ok
318	2026-07-31 14:20:29.837397+00	0	0	1906	1288	0	20	57	120	18	1	0	ok
319	2026-07-31 14:21:29.836918+00	0	0.5	1906	1293	0	20	57	120	17	1	0	ok
320	2026-07-31 14:22:29.838481+00	0.03	0	1906	1293	0	20	57	120	19	1	0	ok
321	2026-07-31 14:23:29.837479+00	0.07	0	1906	1288	0	20	57	120	18	1	0	ok
322	2026-07-31 14:24:29.83887+00	0.02	0	1906	1285	0	20	57	120	18	1	0	ok
323	2026-07-31 14:25:29.838683+00	0.01	0	1906	1290	0	20	57	120	17	1	0	ok
324	2026-07-31 14:26:29.839123+00	0	0	1906	1285	0	20	57	120	16	1	0	ok
325	2026-07-31 14:27:29.837627+00	0	0	1906	1294	0	20	57	121	16	1	0	ok
326	2026-07-31 14:28:29.838317+00	0	0	1906	1291	0	20	57	121	14	1	0	ok
327	2026-07-31 14:29:29.840194+00	0	0	1906	1301	0	20	57	121	14	1	0	ok
328	2026-07-31 14:30:29.838727+00	0.03	0	1906	1285	0	20	57	121	18	1	0	ok
329	2026-07-31 14:31:29.838426+00	0.01	0	1906	1286	0	20	57	121	17	1	0	ok
330	2026-07-31 14:32:29.838589+00	0.04	0	1906	1281	0	20	57	121	18	1	0	ok
331	2026-07-31 14:33:29.83839+00	0.01	0	1906	1280	0	20	57	121	17	1	0	ok
332	2026-07-31 14:34:29.839104+00	0	1	1906	1275	0	20	57	122	18	1	0	ok
333	2026-07-31 14:35:29.838475+00	0	0	1906	1282	0	20	57	121	18	1	0	ok
334	2026-07-31 14:36:29.839195+00	0	0	1906	1280	0	20	57	121	19	1	0	ok
335	2026-07-31 14:37:29.837656+00	0	0	1906	1291	0	20	57	121	18	1	0	ok
336	2026-07-31 14:38:29.838118+00	0	0	1906	1281	0	20	57	121	19	1	0	ok
337	2026-07-31 14:39:29.838165+00	0	0	1906	1286	0	20	57	121	18	1	0	ok
338	2026-07-31 14:40:29.839638+00	0.04	0	1906	1291	0	20	57	122	19	1	0	ok
339	2026-07-31 14:41:29.837957+00	0.11	0	1906	1291	0	20	57	121	17	1	0	ok
340	2026-07-31 14:42:29.837979+00	0.04	0	1906	1291	0	20	57	122	18	1	0	ok
341	2026-07-31 14:43:29.83981+00	0.09	0	1906	1289	0	20	57	121	17	1	0	ok
342	2026-07-31 14:44:29.839114+00	0.03	0	1906	1292	0	20	57	122	18	1	0	ok
343	2026-07-31 14:45:29.837915+00	0.01	0	1906	1288	0	20	57	122	17	1	0	ok
344	2026-07-31 14:46:29.840485+00	0	0	1906	1289	0	20	57	122	18	1	0	ok
345	2026-07-31 14:47:29.84071+00	0	0	1906	1288	0	20	57	122	18	1	0	ok
346	2026-07-31 14:48:29.839403+00	0	0	1906	1277	0	20	57	122	19	1	0	ok
347	2026-07-31 14:49:29.838773+00	0	0	1906	1291	0	20	57	122	18	1	0	ok
348	2026-07-31 14:50:29.839342+00	0	0	1906	1280	0	20	57	123	18	1	0	ok
349	2026-07-31 14:51:29.839637+00	0	0	1906	1291	0	20	57	123	17	1	0	ok
350	2026-07-31 14:52:29.839946+00	0	0	1906	1281	0	20	57	122	18	1	0	ok
351	2026-07-31 14:53:29.838717+00	0	0	1906	1291	0	20	57	122	17	1	0	ok
352	2026-07-31 14:54:29.846355+00	0	0	1906	1286	0	20	57	122	18	1	0	ok
353	2026-07-31 14:55:29.847086+00	0	0	1906	1281	0	20	57	123	17	1	0	ok
354	2026-07-31 14:56:29.846924+00	0	0	1906	1280	0	20	57	122	18	1	0	ok
355	2026-07-31 14:57:29.847321+00	0	0	1906	1293	0	20	57	122	17	1	0	ok
356	2026-07-31 14:58:29.851752+00	0	0	1906	1289	0	20	57	122	19	1	0	ok
357	2026-07-31 14:59:29.848829+00	0.21	0	1906	1292	0	20	57	122	18	1	0	ok
358	2026-07-31 15:00:29.849148+00	0.2	0	1906	1279	0	20	57	122	19	1	0	ok
359	2026-07-31 15:01:29.849932+00	0.07	0	1906	1284	0	20	57	123	17	1	0	ok
360	2026-07-31 15:02:29.847629+00	0.02	0	1906	1284	0	20	57	122	16	1	0	ok
361	2026-07-31 15:03:29.847084+00	0.01	0	1906	1285	0	20	57	122	17	1	0	ok
362	2026-07-31 15:04:29.847387+00	0.04	0	1906	1288	0	20	57	123	18	1	0	ok
363	2026-07-31 15:05:29.846989+00	0.01	0	1906	1292	0	20	57	122	17	1	0	ok
364	2026-07-31 15:06:29.848359+00	0	0	1906	1289	0	20	57	122	18	1	0	ok
365	2026-07-31 15:07:29.848491+00	0	0	1906	1281	0	20	57	122	17	1	0	ok
366	2026-07-31 15:08:29.849421+00	0	0	1906	1276	0	20	57	122	19	1	0	ok
367	2026-07-31 15:09:29.849502+00	0	0	1906	1281	0	20	57	122	18	1	0	ok
368	2026-07-31 15:10:29.851573+00	0	0.51	1906	1290	0	20	57	122	19	1	0	ok
369	2026-07-31 15:11:29.853323+00	0	0	1906	1291	0	20	57	122	18	1	0	ok
370	2026-07-31 15:12:29.855612+00	0	0	1906	1286	0	20	57	122	18	1	0	ok
371	2026-07-31 15:13:29.85575+00	0	0	1906	1279	0	20	57	122	18	1	0	ok
372	2026-07-31 15:14:29.853916+00	0	0	1906	1289	0	20	57	123	19	1	0	ok
373	2026-07-31 15:15:29.855023+00	0	0	1906	1286	0	20	57	122	18	1	0	ok
374	2026-07-31 15:16:29.854625+00	0	0	1906	1280	0	20	57	122	19	1	0	ok
375	2026-07-31 15:17:29.852974+00	0	0	1906	1278	0	20	57	122	18	1	0	ok
376	2026-07-31 15:18:29.854221+00	0.32	0	1906	1285	0	20	57	122	18	1	0	ok
377	2026-07-31 15:19:29.853761+00	0.11	0	1906	1278	0	20	57	122	18	1	0	ok
378	2026-07-31 15:20:29.855365+00	0.83	0	1906	1280	0	20	57	123	18	1	0	ok
379	2026-07-31 15:21:29.856935+00	0.57	0	1906	1292	0	20	57	123	18	1	0	ok
380	2026-07-31 15:22:29.862014+00	0.21	0	1906	1278	0	20	57	123	17	1	0	ok
381	2026-07-31 15:23:29.859675+00	0.44	0	1906	1284	0	20	57	123	17	1	0	ok
382	2026-07-31 15:24:29.861317+00	0.16	0	1906	1287	0	20	57	123	17	1	0	ok
383	2026-07-31 15:25:29.859626+00	0.06	0	1906	1280	0	20	57	124	18	1	0	ok
384	2026-07-31 15:26:29.859937+00	0.02	0	1906	1285	0	20	57	123	16	1	0	ok
385	2026-07-31 15:27:29.860747+00	0.22	0	1906	1289	0	20	57	123	17	1	0	ok
386	2026-07-31 15:28:29.862291+00	0.08	0	1906	1289	0	20	57	123	16	1	0	ok
387	2026-07-31 15:29:29.862993+00	0.03	0	1906	1284	0	20	57	123	16	1	0	ok
388	2026-07-31 15:30:29.864062+00	0.54	0	1906	1284	0	20	57	123	17	1	0	ok
389	2026-07-31 15:31:29.864063+00	0.2	0	1906	1295	0	20	57	124	13	1	0	ok
390	2026-07-31 15:32:29.865535+00	0.07	0	1906	1292	0	20	57	123	16	1	0	ok
391	2026-07-31 15:33:29.868574+00	0.29	0	1906	1281	0	20	57	123	18	1	0	ok
392	2026-07-31 15:34:29.865682+00	0.1	0.5	1906	1287	0	20	57	123	17	1	0	ok
393	2026-07-31 15:35:29.867148+00	0.08	0	1906	1278	0	20	57	123	17	1	0	ok
394	2026-07-31 15:36:29.866221+00	0.35	0	1906	1285	0	20	57	123	16	1	0	ok
395	2026-07-31 15:37:29.867478+00	0.18	0	1906	1293	0	20	57	123	17	1	0	ok
396	2026-07-31 15:38:29.86885+00	0.06	0	1906	1288	0	20	57	124	19	1	0	ok
397	2026-07-31 15:39:29.868071+00	0.13	0	1906	1282	0	20	57	123	17	1	0	ok
398	2026-07-31 15:40:29.872547+00	0.08	0	1906	1278	0	20	57	124	19	1	0	ok
399	2026-07-31 15:41:29.872402+00	0.03	0.5	1906	1291	0	20	57	123	18	1	0	ok
400	2026-07-31 15:42:29.871638+00	0.32	0	1906	1279	0	20	57	124	19	1	0	ok
401	2026-07-31 15:43:29.873756+00	0.38	0.5	1906	1275	0	20	57	124	18	1	0	ok
402	2026-07-31 15:44:29.873063+00	0.14	0	1906	1282	0	20	57	124	17	1	0	ok
403	2026-07-31 15:45:29.875918+00	0.05	0	1906	1275	0	20	57	123	17	1	0	ok
404	2026-07-31 15:46:29.872905+00	0.06	0	1906	1280	0	20	57	123	18	1	0	ok
405	2026-07-31 15:47:29.873473+00	0.28	0	1906	1278	0	20	57	123	18	1	0	ok
406	2026-07-31 15:48:29.873852+00	0.52	0	1906	1277	0	20	57	124	19	1	0	ok
407	2026-07-31 15:49:29.875312+00	0.3	0.5	1906	1289	0	20	57	124	18	1	0	ok
408	2026-07-31 15:50:29.875068+00	0.11	0	1906	1289	0	20	57	124	18	1	0	ok
409	2026-07-31 15:51:29.87897+00	0.14	0	1906	1280	0	20	57	124	18	1	0	ok
410	2026-07-31 15:52:29.879066+00	0.1	0	1906	1283	0	20	57	124	19	1	0	ok
411	2026-07-31 15:53:29.878044+00	0.46	0	1906	1280	0	20	57	124	18	1	0	ok
412	2026-07-31 15:54:29.878847+00	0.17	0	1906	1282	0	20	57	125	19	1	0	ok
413	2026-07-31 15:55:29.877709+00	0.32	0	1906	1280	0	20	57	123	18	1	0	ok
414	2026-07-31 15:56:29.880241+00	0.33	0	1906	1284	0	20	57	123	18	1	0	ok
415	2026-07-31 15:57:29.88527+00	0.12	0	1906	1289	0	20	57	123	17	1	0	ok
416	2026-07-31 15:58:29.881018+00	0.31	0	1906	1276	0	20	57	124	18	1	0	ok
417	2026-07-31 15:59:29.882673+00	0.11	0	1906	1295	0	20	57	123	14	1	0	ok
418	2026-07-31 16:00:29.883583+00	0.67	0	1906	1296	0	20	57	123	14	1	0	ok
419	2026-07-31 16:01:29.882927+00	0.25	0.5	1906	1285	0	20	57	124	18	1	0	ok
420	2026-07-31 16:02:29.883698+00	0.39	0	1906	1286	0	20	57	124	18	1	0	ok
421	2026-07-31 16:03:29.883623+00	0.28	0	1906	1292	0	20	57	123	15	1	0	ok
422	2026-07-31 16:04:29.886897+00	0.1	0	1906	1298	0	20	57	123	13	1	0	ok
423	2026-07-31 16:05:29.884721+00	0.62	0	1906	1299	0	20	57	124	11	1	0	ok
424	2026-07-31 16:06:29.884695+00	0.49	0	1906	1299	0	20	57	124	11	1	0	ok
425	2026-07-31 16:07:29.887384+00	0.55	0	1906	1294	0	20	57	125	13	1	0	ok
426	2026-07-31 16:08:29.888467+00	0.62	0	1906	1296	0	20	57	125	13	1	0	ok
427	2026-07-31 16:09:29.887182+00	0.28	0	1906	1293	0	20	57	124	12	1	0	ok
428	2026-07-31 16:10:29.887418+00	0.1	0	1906	1298	0	20	57	115	14	1	0	ok
429	2026-07-31 16:11:29.889919+00	0.3	0	1906	1287	0	20	57	118	18	1	0	ok
430	2026-07-31 16:12:29.889797+00	0.32	0	1906	1281	0	20	57	120	18	1	0	ok
431	2026-07-31 16:13:29.888872+00	0.19	0	1906	1283	0	20	57	122	17	1	0	ok
432	2026-07-31 16:14:29.889855+00	0.38	0	1906	1283	0	20	57	122	19	1	0	ok
433	2026-07-31 16:15:29.890036+00	0.14	0	1906	1289	0	20	57	122	16	1	0	ok
434	2026-07-31 16:16:29.89039+00	0.21	0	1906	1290	0	20	57	122	16	1	0	ok
435	2026-07-31 16:17:29.891347+00	0.07	0	1906	1287	0	20	57	122	16	1	0	ok
436	2026-07-31 16:18:29.892904+00	0.29	0	1906	1283	0	20	57	122	18	1	0	ok
437	2026-07-31 16:19:29.892629+00	0.42	0	1906	1289	0	20	57	122	18	1	0	ok
438	2026-07-31 16:20:29.89354+00	0.31	0	1906	1291	0	20	57	122	17	1	0	ok
439	2026-07-31 16:21:29.894814+00	0.11	0	1906	1288	0	20	57	123	17	1	0	ok
440	2026-07-31 16:22:29.894459+00	0.3	0	1906	1283	0	20	57	122	18	1	0	ok
441	2026-07-31 16:23:29.893694+00	0.27	0	1906	1283	0	20	57	122	17	1	0	ok
442	2026-07-31 16:24:29.89373+00	0.31	0	1906	1280	0	20	57	123	19	1	0	ok
443	2026-07-31 16:25:29.894269+00	0.31	0	1906	1276	0	20	57	122	16	1	0	ok
444	2026-07-31 16:26:29.897525+00	0.11	0	1906	1289	0	20	57	124	15	1	0	ok
445	2026-07-31 16:27:29.898022+00	0.3	0	1906	1290	0	20	57	124	14	1	0	ok
446	2026-07-31 16:28:29.89665+00	0.43	0	1906	1282	0	20	57	123	14	1	0	ok
447	2026-07-31 16:29:29.897871+00	0.15	0	1906	1280	0	20	57	123	16	1	0	ok
448	2026-07-31 16:30:29.89743+00	0.06	0	1906	1290	0	20	57	123	17	1	0	ok
449	2026-07-31 16:31:29.895563+00	0.28	0	1906	1280	0	20	57	123	17	1	0	ok
450	2026-07-31 16:32:29.896939+00	0.21	0	1906	1279	0	20	57	122	18	1	0	ok
451	2026-07-31 16:33:29.897495+00	0.07	0	1906	1280	0	20	57	123	16	1	0	ok
452	2026-07-31 16:34:29.897403+00	0.29	0	1906	1284	0	20	57	124	12	1	0	ok
453	2026-07-31 16:35:29.898704+00	0.27	0	1906	1282	0	20	57	123	17	1	0	ok
454	2026-07-31 16:36:29.897789+00	0.36	0	1906	1284	0	20	57	123	18	1	0	ok
455	2026-07-31 16:37:29.897775+00	0.39	0	1906	1292	0	20	57	122	17	1	0	ok
456	2026-07-31 16:38:29.898927+00	0.14	0	1906	1282	0	20	57	123	18	1	0	ok
457	2026-07-31 16:39:29.896773+00	0.05	0	1906	1277	0	20	57	123	17	1	0	ok
458	2026-07-31 16:40:29.896548+00	0.33	0	1906	1287	0	20	57	123	13	1	0	ok
459	2026-07-31 16:41:29.89978+00	0.12	0	1906	1288	0	20	57	123	15	1	0	ok
460	2026-07-31 16:42:29.898877+00	0.04	0	1906	1287	0	20	57	123	19	1	0	ok
461	2026-07-31 16:43:29.896618+00	0.01	0	1906	1285	0	20	57	123	17	1	0	ok
462	2026-07-31 16:44:29.900282+00	0	0	1906	1288	0	20	57	123	19	1	0	ok
463	2026-07-31 16:45:29.900776+00	0.42	0	1906	1283	0	20	57	123	18	1	0	ok
464	2026-07-31 16:46:29.900114+00	0.18	0	1906	1283	0	20	57	123	19	1	0	ok
465	2026-07-31 16:47:29.898852+00	0.07	0	1906	1279	0	20	57	123	18	1	0	ok
466	2026-07-31 16:47:33.170184+00	0.06	0	1906	1351	0	20	57	100	12	1	0	ok
467	2026-07-31 16:48:33.167682+00	0.2	0	1906	1323	0	20	57	92	10	1	0	ok
468	2026-07-31 16:49:33.168736+00	0.22	0	1906	1311	0	20	57	93	10	1	0	ok
469	2026-07-31 16:50:33.165519+00	0.08	0	1906	1312	0	20	57	96	10	1	0	ok
470	2026-07-31 16:51:33.171512+00	0.12	0	1906	1305	0	20	57	98	11	1	0	ok
471	2026-07-31 16:52:18.167794+00	0.24	0	1906	1335	0	20	57	99	12	1	0	ok
472	2026-07-31 16:53:18.165279+00	0.13	0	1906	1306	0	20	57	90	17	1	0	ok
473	2026-07-31 16:54:18.166691+00	0.05	0	1906	1309	0	20	57	94	18	1	0	ok
474	2026-07-31 16:55:18.166509+00	0.02	0	1906	1305	0	20	57	96	16	1	0	ok
475	2026-07-31 16:56:18.167706+00	0	0	1906	1290	0	20	57	103	18	1	0	ok
476	2026-07-31 16:57:18.166899+00	0	0	1906	1307	0	20	57	98	16	1	0	ok
477	2026-07-31 16:58:18.167131+00	0	0	1906	1297	0	20	57	100	15	1	0	ok
478	2026-07-31 16:59:18.168619+00	0.25	0	1906	1303	0	20	57	103	14	1	0	ok
479	2026-07-31 17:00:18.168729+00	0.46	0	1906	1300	0	20	57	104	13	1	0	ok
480	2026-07-31 17:01:18.168243+00	0.41	0	1906	1311	0	20	57	106	11	1	0	ok
481	2026-07-31 17:02:18.170384+00	0.15	0	1906	1300	0	20	57	104	13	1	0	ok
482	2026-07-31 17:02:48.587381+00	0.17	0.5	1906	1341	0	20	57	99	12	1	0	ok
483	2026-07-31 17:03:48.586847+00	0.06	0	1906	1327	0	20	57	91	10	1	0	ok
484	2026-07-31 17:04:48.584865+00	0.02	0	1906	1324	0	20	57	93	10	1	0	ok
485	2026-07-31 17:05:48.586723+00	0.18	0	1906	1324	0	20	57	96	10	1	0	ok
486	2026-07-31 17:06:48.589841+00	0.15	0	1906	1320	0	20	57	98	11	1	0	ok
487	2026-07-31 17:06:51.286998+00	0.15	0	1906	1332	0	20	57	98	12	1	0	ok
488	2026-07-31 17:07:51.285294+00	0.05	0	1906	1330	0	20	57	91	10	1	0	ok
489	2026-07-31 17:08:51.285485+00	0.02	0	1906	1314	0	20	57	94	12	1	0	ok
490	2026-07-31 17:09:51.28529+00	0	0	1906	1317	0	20	57	98	12	1	0	ok
491	2026-07-31 17:10:51.28897+00	0	0	1906	1321	0	20	57	102	12	1	0	ok
492	2026-07-31 17:11:51.287317+00	0	0	1906	1303	0	20	57	110	17	1	0	ok
493	2026-07-31 17:12:51.288438+00	0	0	1906	1305	0	20	57	112	11	1	0	ok
494	2026-07-31 17:13:51.288345+00	0	0	1906	1309	0	20	57	112	12	1	0	ok
495	2026-07-31 17:14:51.288507+00	0	0	1906	1305	0	20	57	113	13	1	0	ok
496	2026-07-31 17:15:51.289535+00	0	0	1906	1313	0	20	57	113	12	1	0	ok
497	2026-07-31 17:16:51.289113+00	0	0	1906	1304	0	20	57	113	12	1	0	ok
498	2026-07-31 17:17:51.291163+00	0.17	0	1906	1306	0	20	57	113	12	1	0	ok
499	2026-07-31 17:18:51.307306+00	0.14	0	1906	1289	0	20	57	114	14	1	0	ok
500	2026-07-31 17:19:51.291827+00	0.08	0	1906	1308	0	20	57	114	13	1	0	ok
501	2026-07-31 17:20:51.290555+00	0.03	0	1906	1306	0	20	57	114	13	1	0	ok
502	2026-07-31 17:21:51.290309+00	0.01	0	1906	1304	0	20	57	114	11	1	0	ok
503	2026-07-31 17:22:51.292088+00	0	0	1906	1311	0	20	57	114	13	1	0	ok
504	2026-07-31 17:23:51.290324+00	0	0	1906	1309	0	20	57	115	11	1	0	ok
505	2026-07-31 17:24:51.294749+00	0.19	0	1906	1312	0	20	57	114	13	1	0	ok
506	2026-07-31 17:25:37.905026+00	0.08	0	1906	1334	0	20	57	98	12	1	0	ok
507	2026-07-31 17:26:37.905243+00	0.03	0	1906	1310	0	20	57	95	12	1	0	ok
508	2026-07-31 17:27:37.90441+00	0.07	0	1906	1319	0	20	57	101	13	1	0	ok
509	2026-07-31 17:28:37.90488+00	0.11	0.5	1906	1300	0	20	57	112	12	1	0	ok
510	2026-07-31 17:29:37.90651+00	0.04	0	1906	1299	0	20	57	108	14	1	0	ok
511	2026-07-31 17:30:37.903916+00	0.01	0	1906	1297	0	20	57	111	12	1	0	ok
512	2026-07-31 17:31:37.906161+00	0	0	1906	1292	0	20	57	113	12	1	0	ok
513	2026-07-31 17:32:37.905899+00	0.16	0	1906	1303	0	20	57	114	12	1	0	ok
514	2026-07-31 17:33:37.906553+00	0.06	0	1906	1301	0	20	57	113	12	1	0	ok
515	2026-07-31 17:34:37.906163+00	0.08	0	1906	1299	0	20	57	114	12	1	0	ok
516	2026-07-31 17:35:37.908347+00	0.13	0	1906	1299	0	20	57	114	9	1	0	ok
517	2026-07-31 17:36:37.908217+00	0.08	0	1906	1286	0	20	57	115	15	1	0	ok
518	2026-07-31 17:37:37.909175+00	0.03	0	1906	1299	0	20	57	115	10	1	0	ok
519	2026-07-31 17:38:37.907781+00	0.01	0	1906	1302	0	20	57	115	10	1	0	ok
520	2026-07-31 17:39:37.908494+00	0	0	1906	1303	0	20	57	115	11	1	0	ok
521	2026-07-31 17:40:37.90795+00	0	0	1906	1298	0	20	57	116	11	1	0	ok
522	2026-07-31 17:41:37.908616+00	0	0	1906	1295	0	20	57	116	14	1	0	ok
523	2026-07-31 17:42:37.906174+00	0	0	1906	1302	0	20	57	116	10	1	0	ok
524	2026-07-31 17:43:37.910761+00	0	0	1906	1295	0	20	57	116	13	1	0	ok
525	2026-07-31 17:44:16.93027+00	0.05	0	1906	1333	0	20	57	98	12	1	0	ok
526	2026-07-31 17:45:16.934149+00	0.02	0	1906	1310	0	20	57	91	17	1	0	ok
527	2026-07-31 17:46:16.932596+00	0	0	1906	1302	0	20	57	98	18	1	0	ok
528	2026-07-31 17:47:16.932517+00	0	0	1906	1306	0	20	57	100	18	1	0	ok
529	2026-07-31 17:48:16.935426+00	0	0	1906	1287	0	20	57	102	17	1	0	ok
530	2026-07-31 17:48:27.725766+00	0	0	1906	1338	0	20	57	98	12	1	0	ok
531	2026-07-31 17:49:27.725502+00	0	0	1906	1314	0	20	57	93	17	1	0	ok
532	2026-07-31 17:50:27.727189+00	0	0	1906	1300	0	20	57	97	17	1	0	ok
533	2026-07-31 17:51:27.726559+00	0	0	1906	1301	0	20	57	97	18	1	0	ok
534	2026-07-31 17:52:27.726955+00	0	0	1906	1302	0	20	57	101	18	1	0	ok
535	2026-07-31 17:53:27.72869+00	0	0	1906	1301	0	20	57	96	19	1	0	ok
536	2026-07-31 17:54:27.7273+00	0	0	1906	1301	0	20	57	97	19	1	0	ok
537	2026-07-31 17:55:27.728427+00	0	0	1906	1306	0	20	57	100	17	1	0	ok
538	2026-07-31 17:56:27.726703+00	0	0	1906	1300	0	20	57	102	16	1	0	ok
539	2026-07-31 17:57:27.727008+00	0	0.5	1906	1308	0	20	57	103	16	1	0	ok
540	2026-07-31 17:58:27.726643+00	0	0	1906	1301	0	20	57	103	14	1	0	ok
541	2026-07-31 17:59:27.726916+00	0	0	1906	1302	0	20	57	103	16	1	0	ok
542	2026-07-31 18:00:28.623045+00	0.1	0	1906	1335	0	20	57	98	12	1	0	ok
543	2026-07-31 18:01:28.621726+00	0.1	0	1906	1310	0	20	57	98	15	1	0	ok
544	2026-07-31 18:02:28.623771+00	0.04	0	1906	1298	0	20	57	99	16	1	0	ok
545	2026-07-31 18:03:28.621652+00	0.01	0	1906	1302	0	20	57	106	16	1	0	ok
546	2026-07-31 18:04:28.622504+00	0	0	1906	1285	0	20	57	102	19	1	0	ok
547	2026-07-31 18:05:28.623379+00	0	0	1906	1294	0	20	57	106	17	1	0	ok
548	2026-07-31 18:06:28.623002+00	0	0	1906	1285	0	20	57	108	19	1	0	ok
549	2026-07-31 18:07:28.624556+00	0	0	1906	1297	0	20	57	110	17	1	0	ok
550	2026-07-31 18:08:28.625905+00	0	0	1906	1297	0	20	57	109	18	1	0	ok
551	2026-07-31 18:08:31.060862+00	0	0.5	1906	1337	0	20	57	99	12	1	0	ok
552	2026-07-31 18:09:31.040996+00	0	0	1906	1312	0	20	57	96	14	1	0	ok
553	2026-07-31 18:10:31.039885+00	0.04	0	1906	1300	0	20	57	99	10	1	0	ok
554	2026-07-31 18:11:31.03925+00	0.01	0	1906	1300	0	20	57	103	10	1	0	ok
555	2026-07-31 18:12:31.03922+00	0	0	1906	1296	0	20	57	105	10	1	0	ok
556	2026-07-31 18:13:31.042602+00	0	0	1906	1305	0	20	57	101	10	1	0	ok
557	2026-07-31 18:14:31.042596+00	0	0.5	1906	1302	0	20	57	104	10	1	0	ok
558	2026-07-31 18:15:31.045459+00	0	0	1906	1298	0	20	57	105	10	1	0	ok
559	2026-07-31 18:16:31.042629+00	0	0	1906	1306	0	20	57	107	10	1	0	ok
560	2026-07-31 18:17:31.043257+00	0	0	1906	1282	0	20	57	106	19	1	0	ok
561	2026-07-31 18:18:31.043372+00	0	0	1906	1283	0	20	57	107	9	1	0	ok
562	2026-07-31 18:19:31.042354+00	0	0	1906	1290	0	20	57	107	8	1	0	ok
563	2026-07-31 18:20:31.042534+00	0	0	1906	1291	0	20	57	107	20	1	0	ok
564	2026-07-31 18:21:31.040601+00	0	0	1906	1293	0	20	57	104	11	0	0	ok
565	2026-07-31 18:22:31.041549+00	0	0	1906	1302	0	20	57	105	11	0	0	ok
566	2026-07-31 18:23:31.043218+00	0.07	0	1906	1299	0	20	57	107	11	0	0	ok
567	2026-07-31 18:24:31.044762+00	0.02	0	1906	1297	0	20	57	110	15	0	0	ok
568	2026-07-31 18:25:31.044478+00	0.01	0	1906	1284	0	20	57	110	12	0	0	ok
569	2026-07-31 18:26:31.045072+00	0	0.5	1906	1285	0	20	57	110	11	0	0	ok
570	2026-07-31 18:27:31.045105+00	0	0	1906	1289	0	20	58	111	11	1	0	ok
571	2026-07-31 18:28:31.049371+00	0	0	1906	1283	0	20	58	110	11	1	0	ok
572	2026-07-31 18:29:31.049392+00	0	0	1906	1294	0	20	58	111	11	1	0	ok
573	2026-07-31 18:30:31.049053+00	0	0	1906	1285	0	20	58	111	11	1	0	ok
574	2026-07-31 18:31:31.118423+00	0	0.5	1906	1286	0	20	58	104	15	1	0	ok
575	2026-07-31 18:32:31.13164+00	0	0	1906	1290	0	20	58	106	13	1	0	ok
576	2026-07-31 18:33:31.132945+00	0	0	1906	1287	0	20	58	107	13	1	0	ok
577	2026-07-31 18:34:31.130384+00	0	0	1906	1291	0	20	58	108	13	1	0	ok
578	2026-07-31 18:35:31.1295+00	0.03	0	1906	1290	0	20	58	108	12	1	0	ok
579	2026-07-31 18:36:31.130968+00	0.01	0	1906	1288	0	20	58	109	12	1	0	ok
580	2026-07-31 18:37:31.129668+00	0	0	1906	1294	0	20	58	111	11	1	0	ok
581	2026-07-31 18:38:31.1326+00	0	0	1906	1292	0	20	58	111	12	1	0	ok
582	2026-07-31 18:39:31.13081+00	0	0	1906	1288	0	20	58	112	18	1	0	ok
583	2026-07-31 18:40:31.130431+00	0	0	1906	1287	0	20	58	112	11	1	0	ok
584	2026-07-31 18:41:31.132015+00	0	0	1906	1293	0	20	58	112	13	1	0	ok
585	2026-07-31 18:42:31.131461+00	0	0	1906	1284	0	20	58	119	11	1	0	ok
586	2026-07-31 18:43:31.131835+00	0	0	1906	1284	0	20	58	120	15	1	0	ok
587	2026-07-31 18:44:31.133611+00	0	0	1906	1278	0	20	58	119	11	1	0	ok
588	2026-07-31 18:45:31.13315+00	0	0	1906	1288	0	20	58	119	11	1	0	ok
589	2026-07-31 18:46:31.133691+00	0	0	1906	1278	0	20	58	119	11	1	0	ok
590	2026-07-31 18:47:31.132091+00	0	0	1906	1291	0	20	58	119	11	1	0	ok
591	2026-07-31 18:48:31.132237+00	0	0	1906	1284	0	20	58	120	11	1	0	ok
592	2026-07-31 18:49:31.132395+00	0	0	1906	1293	0	20	58	120	11	1	0	ok
593	2026-07-31 18:50:31.135503+00	0	0	1906	1299	0	20	58	120	11	1	0	ok
594	2026-07-31 18:51:31.134541+00	0	0	1906	1291	0	20	58	119	11	1	0	ok
595	2026-07-31 18:52:31.133953+00	0	0	1906	1294	0	20	58	119	11	1	0	ok
596	2026-07-31 18:53:31.133731+00	0	0	1906	1292	0	20	58	119	11	1	0	ok
597	2026-07-31 18:54:31.137079+00	0	0	1906	1291	0	20	58	119	11	1	0	ok
598	2026-07-31 18:55:31.133375+00	0	0	1906	1292	0	20	58	119	11	1	0	ok
599	2026-07-31 18:56:31.133518+00	0	0	1906	1290	0	20	58	120	11	1	0	ok
600	2026-07-31 18:57:31.133627+00	0	0.5	1906	1295	0	20	58	120	11	1	0	ok
601	2026-07-31 18:58:31.134155+00	0	0	1906	1283	0	20	58	121	11	1	0	ok
602	2026-07-31 18:59:31.135097+00	0.08	0	1906	1293	0	20	58	119	11	1	0	ok
603	2026-07-31 19:00:31.134712+00	0.03	0	1906	1280	0	20	58	120	11	1	0	ok
604	2026-07-31 19:01:31.133662+00	0.01	0	1906	1295	0	20	58	119	11	1	0	ok
605	2026-07-31 19:02:31.137164+00	0	0	1906	1282	0	20	58	120	11	1	0	ok
606	2026-07-31 19:03:31.137226+00	0	0	1906	1284	0	20	58	119	11	1	0	ok
607	2026-07-31 19:04:31.1368+00	0	0	1906	1282	0	20	58	120	11	1	0	ok
608	2026-07-31 19:05:31.140644+00	0	0	1906	1281	0	20	58	119	11	1	0	ok
609	2026-07-31 19:06:31.138176+00	0	0	1906	1280	0	20	58	120	11	1	0	ok
610	2026-07-31 19:07:31.135557+00	0	0	1906	1283	0	20	58	121	11	1	0	ok
611	2026-07-31 19:08:31.135613+00	0	0	1906	1290	0	20	58	120	11	1	0	ok
612	2026-07-31 19:09:31.13894+00	0	0	1906	1286	0	20	58	120	11	1	0	ok
613	2026-07-31 19:10:31.137995+00	0	0	1906	1282	0	20	58	120	11	1	0	ok
614	2026-07-31 19:11:31.136083+00	0	0	1906	1282	0	20	58	120	11	1	0	ok
615	2026-07-31 19:12:31.137336+00	0	0	1906	1284	0	20	58	121	11	1	0	ok
616	2026-07-31 19:13:31.137579+00	0	0	1906	1291	0	20	58	121	11	1	0	ok
617	2026-07-31 19:14:31.137495+00	0.03	0	1906	1281	0	20	58	122	11	1	0	ok
618	2026-07-31 19:15:31.138681+00	0.01	0	1906	1286	0	20	58	121	11	1	0	ok
619	2026-07-31 19:16:31.139841+00	0	0	1906	1281	0	20	58	122	12	1	0	ok
620	2026-07-31 19:17:31.140812+00	0	0	1906	1296	0	20	58	122	11	1	0	ok
621	2026-07-31 19:18:31.140668+00	0	0	1906	1282	0	20	58	122	11	1	0	ok
622	2026-07-31 19:19:31.139668+00	0	0	1906	1282	0	20	58	122	11	1	0	ok
623	2026-07-31 19:20:31.140539+00	0	0	1906	1293	0	20	58	122	11	1	0	ok
624	2026-07-31 19:21:31.140228+00	0	0	1906	1278	0	20	58	122	10	1	0	ok
625	2026-07-31 19:22:31.141617+00	0	0	1906	1285	0	20	58	122	10	1	0	ok
626	2026-07-31 19:23:31.140954+00	0	0	1906	1285	0	20	58	121	10	1	0	ok
627	2026-07-31 19:24:31.141951+00	0	0	1906	1284	0	20	58	122	11	1	0	ok
628	2026-07-31 19:25:31.140751+00	0	0	1906	1272	0	20	58	121	10	1	0	ok
629	2026-07-31 19:26:31.14181+00	0	0	1906	1279	0	20	58	121	11	1	0	ok
630	2026-07-31 19:27:31.142993+00	0	0	1906	1280	0	20	58	121	10	1	0	ok
631	2026-07-31 19:28:31.143829+00	0	0	1906	1281	0	20	58	122	10	1	0	ok
632	2026-07-31 19:29:31.141533+00	0	0	1906	1272	0	20	58	121	10	1	0	ok
633	2026-07-31 19:30:31.147409+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
634	2026-07-31 19:31:31.144602+00	0	0	1906	1287	0	20	58	121	11	1	0	ok
635	2026-07-31 19:32:31.147847+00	0	0	1906	1281	0	20	58	121	10	1	0	ok
636	2026-07-31 19:33:31.146304+00	0	0	1906	1279	0	20	58	122	10	1	0	ok
637	2026-07-31 19:34:31.14796+00	0	0	1906	1287	0	20	58	121	10	1	0	ok
638	2026-07-31 19:35:31.14894+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
639	2026-07-31 19:36:31.148283+00	0	0	1906	1282	0	20	58	122	10	1	0	ok
640	2026-07-31 19:37:31.147455+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
641	2026-07-31 19:38:31.147664+00	0	0	1906	1283	0	20	58	121	10	1	0	ok
642	2026-07-31 19:39:31.147831+00	0	0	1906	1284	0	20	58	122	10	1	0	ok
643	2026-07-31 19:40:31.147945+00	0	0	1906	1289	0	20	58	121	10	1	0	ok
644	2026-07-31 19:41:31.1478+00	0	0	1906	1294	0	20	58	122	10	1	0	ok
645	2026-07-31 19:42:31.151097+00	0	0.5	1906	1289	0	20	58	122	10	1	0	ok
646	2026-07-31 19:43:31.150483+00	0	0	1906	1293	0	20	58	121	10	1	0	ok
647	2026-07-31 19:44:31.15179+00	0	0	1906	1294	0	20	58	122	10	1	0	ok
648	2026-07-31 19:45:31.148858+00	0	0	1906	1288	0	20	58	122	10	1	0	ok
649	2026-07-31 19:46:31.149402+00	0	0	1906	1278	0	20	58	122	10	1	0	ok
650	2026-07-31 19:47:31.148927+00	0	0	1906	1282	0	20	58	122	11	1	0	ok
651	2026-07-31 19:48:31.148894+00	0	0	1906	1289	0	20	58	122	11	1	0	ok
652	2026-07-31 19:49:31.14907+00	0	0	1906	1286	0	20	58	122	11	1	0	ok
653	2026-07-31 19:50:31.149824+00	0	0	1906	1294	0	20	58	122	10	1	0	ok
654	2026-07-31 19:51:31.150859+00	0	0	1906	1279	0	20	58	122	11	1	0	ok
655	2026-07-31 19:52:31.155801+00	0	0	1906	1278	0	20	58	121	14	1	0	ok
656	2026-07-31 19:53:31.1547+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
657	2026-07-31 19:54:31.155563+00	0	0	1906	1288	0	20	58	122	10	1	0	ok
658	2026-07-31 19:55:31.155782+00	0	0	1906	1287	0	20	58	121	10	1	0	ok
659	2026-07-31 19:56:31.156514+00	0	0.5	1906	1286	0	20	58	121	10	1	0	ok
660	2026-07-31 19:57:31.155607+00	0	0	1906	1285	0	20	58	122	9	1	0	ok
661	2026-07-31 19:58:31.155327+00	0	0	1906	1282	0	20	58	123	10	1	0	ok
662	2026-07-31 19:59:31.155304+00	0	0	1906	1287	0	20	58	122	10	1	0	ok
663	2026-07-31 20:00:31.154814+00	0	0	1906	1278	0	20	58	121	10	1	0	ok
664	2026-07-31 20:01:31.156702+00	0	0	1906	1270	0	20	58	122	10	1	0	ok
665	2026-07-31 20:02:31.158376+00	0	0	1906	1286	0	20	58	122	10	1	0	ok
666	2026-07-31 20:03:31.160241+00	0	0	1906	1279	0	20	58	122	10	1	0	ok
667	2026-07-31 20:04:31.161772+00	0	0	1906	1285	0	20	58	122	10	1	0	ok
668	2026-07-31 20:05:31.158973+00	0	0	1906	1284	0	20	58	122	11	1	0	ok
669	2026-07-31 20:06:31.159779+00	0	0	1906	1281	0	20	58	122	11	1	0	ok
670	2026-07-31 20:07:31.161163+00	0	0	1906	1278	0	20	58	122	11	1	0	ok
671	2026-07-31 20:08:31.161052+00	0	0	1906	1275	0	20	58	125	11	1	0	ok
672	2026-07-31 20:09:31.161244+00	0	0	1906	1280	0	20	58	125	11	1	0	ok
673	2026-07-31 20:10:31.162272+00	0	0	1906	1280	0	20	58	125	11	1	0	ok
674	2026-07-31 20:11:31.163438+00	0.16	0	1906	1278	0	20	58	125	12	1	0	ok
675	2026-07-31 20:12:31.163178+00	0.06	0	1906	1274	0	20	58	124	12	1	0	ok
676	2026-07-31 20:13:31.162492+00	0.02	0	1906	1288	0	20	58	125	12	1	0	ok
677	2026-07-31 20:14:31.162962+00	0	0	1906	1278	0	20	58	126	12	1	0	ok
678	2026-07-31 20:15:31.162037+00	0	0	1906	1292	0	20	58	125	12	1	0	ok
679	2026-07-31 20:16:31.163842+00	0	0	1906	1286	0	20	58	125	11	1	0	ok
680	2026-07-31 20:17:31.163281+00	0	0	1906	1293	0	20	58	117	11	1	0	ok
681	2026-07-31 20:18:31.163755+00	0	0	1906	1292	0	20	58	118	12	1	0	ok
682	2026-07-31 20:19:31.164514+00	0	0	1906	1278	0	20	58	118	12	1	0	ok
683	2026-07-31 20:20:31.163344+00	0	0	1906	1294	0	20	58	119	12	1	0	ok
684	2026-07-31 20:21:31.162275+00	0	0	1906	1284	0	20	58	120	12	1	0	ok
685	2026-07-31 20:22:31.164804+00	0	0	1906	1280	0	20	58	121	12	1	0	ok
686	2026-07-31 20:23:31.164503+00	0	0	1906	1276	0	20	58	123	12	1	0	ok
687	2026-07-31 20:24:31.167639+00	0	0	1906	1276	0	20	58	122	12	1	0	ok
688	2026-07-31 20:25:31.164724+00	0	0	1906	1280	0	20	58	123	12	1	0	ok
689	2026-07-31 20:26:31.167811+00	0	0	1906	1269	0	20	58	123	12	1	0	ok
690	2026-07-31 20:27:31.167677+00	0	0	1906	1266	0	20	58	124	11	1	0	ok
691	2026-07-31 20:28:31.169699+00	0	0	1906	1271	0	20	58	124	10	1	0	ok
692	2026-07-31 20:29:31.170789+00	0	0	1906	1271	0	20	58	124	10	1	0	ok
693	2026-07-31 20:30:31.16989+00	0	0	1906	1267	0	20	58	124	10	1	0	ok
694	2026-07-31 20:31:31.172897+00	0	0	1906	1272	0	20	58	124	10	1	0	ok
695	2026-07-31 20:32:31.170586+00	0.08	0	1906	1274	0	20	58	124	10	1	0	ok
696	2026-07-31 20:33:31.169474+00	0.03	0	1906	1285	0	20	58	124	10	1	0	ok
697	2026-07-31 20:34:31.171847+00	0.01	0.5	1906	1268	0	20	58	124	10	1	0	ok
698	2026-07-31 20:35:31.171777+00	0.26	0	1906	1281	0	20	58	124	10	1	0	ok
699	2026-07-31 20:36:31.172532+00	0.09	0	1906	1284	0	20	58	124	10	1	0	ok
700	2026-07-31 20:37:31.170988+00	0.22	0	1906	1286	0	20	58	124	10	1	0	ok
701	2026-07-31 20:38:31.17558+00	0.45	0	1906	1292	0	20	58	124	10	1	0	ok
702	2026-07-31 20:39:31.173634+00	0.49	0	1906	1289	0	20	58	124	10	1	0	ok
703	2026-07-31 20:40:31.177654+00	0.18	0	1906	1280	0	20	58	125	10	1	0	ok
704	2026-07-31 20:41:31.17761+00	0.14	0	1906	1279	0	20	58	124	10	1	0	ok
705	2026-07-31 20:42:31.176666+00	0.13	0	1906	1282	0	20	58	124	10	1	0	ok
706	2026-07-31 20:43:31.178658+00	0.05	0	1906	1283	0	20	58	124	10	1	0	ok
707	2026-07-31 20:44:31.178056+00	0.02	0	1906	1284	0	20	58	124	10	1	0	ok
708	2026-07-31 20:45:31.178793+00	0	0	1906	1287	0	20	58	124	10	1	0	ok
709	2026-07-31 20:46:31.179169+00	0	0	1906	1270	0	20	58	124	10	1	0	ok
710	2026-07-31 20:47:31.179801+00	0	0	1906	1287	0	20	58	124	10	1	0	ok
711	2026-07-31 20:48:31.180224+00	0	0	1906	1276	0	20	58	124	10	1	0	ok
712	2026-07-31 20:49:31.18188+00	0.05	0	1906	1279	0	20	58	124	10	1	0	ok
713	2026-07-31 20:50:31.179552+00	0.02	0	1906	1274	0	20	58	124	10	1	0	ok
714	2026-07-31 20:51:31.18023+00	0	0	1906	1272	0	20	58	124	10	1	0	ok
715	2026-07-31 20:52:31.179561+00	0	0.5	1906	1278	0	20	58	124	10	1	0	ok
716	2026-07-31 20:53:31.18185+00	0	0	1906	1287	0	20	58	124	10	1	0	ok
717	2026-07-31 20:54:31.180565+00	0	0	1906	1274	0	20	58	124	10	1	0	ok
718	2026-07-31 20:55:31.17989+00	0	0	1906	1282	0	20	58	124	10	1	0	ok
719	2026-07-31 20:56:31.1798+00	0	0.5	1906	1276	0	20	58	124	10	1	0	ok
720	2026-07-31 20:57:31.181842+00	0	0	1906	1283	0	20	58	124	10	1	0	ok
721	2026-07-31 20:58:31.179779+00	0	0	1906	1280	0	20	58	125	10	1	0	ok
722	2026-07-31 20:59:31.180351+00	0	0	1906	1282	0	20	58	124	10	1	0	ok
723	2026-07-31 21:00:31.180311+00	0.08	0	1906	1279	0	20	58	124	10	1	0	ok
724	2026-07-31 21:01:31.18003+00	0.03	0	1906	1285	0	20	58	125	10	1	0	ok
725	2026-07-31 21:02:31.179492+00	0.01	0	1906	1273	0	20	58	125	10	1	0	ok
726	2026-07-31 21:03:31.180192+00	0	0	1906	1270	0	20	58	124	10	1	0	ok
727	2026-07-31 21:04:31.180368+00	0.16	0	1906	1273	0	20	58	125	10	1	0	ok
728	2026-07-31 21:05:31.179379+00	0.06	0	1906	1281	0	20	58	125	10	1	0	ok
729	2026-07-31 21:06:31.179446+00	0.05	0.5	1906	1283	0	20	58	125	10	1	0	ok
730	2026-07-31 21:07:31.180449+00	0.02	0	1906	1276	0	20	58	125	10	1	0	ok
731	2026-07-31 21:08:31.179863+00	0	0	1906	1275	0	20	58	125	10	1	0	ok
732	2026-07-31 21:09:31.183419+00	0.15	0	1906	1278	0	20	58	125	10	1	0	ok
733	2026-07-31 21:10:31.180217+00	0.05	0	1906	1275	0	20	58	125	10	1	0	ok
734	2026-07-31 21:11:31.179562+00	0.02	0	1906	1285	0	20	58	125	10	1	0	ok
735	2026-07-31 21:12:31.179102+00	0	0	1906	1271	0	20	58	125	10	1	0	ok
736	2026-07-31 21:13:31.182695+00	0.16	0	1906	1283	0	20	58	124	10	1	0	ok
737	2026-07-31 21:14:31.182544+00	0.14	0	1906	1282	0	20	58	125	10	1	0	ok
738	2026-07-31 21:15:31.182844+00	0.05	0	1906	1294	0	20	58	125	10	1	0	ok
739	2026-07-31 21:16:31.186975+00	0.02	0	1906	1277	0	20	58	124	10	1	0	ok
740	2026-07-31 21:17:31.183178+00	0	0	1906	1277	0	20	58	125	10	1	0	ok
741	2026-07-31 21:18:31.182721+00	0	0	1906	1281	0	20	58	124	10	1	0	ok
742	2026-07-31 21:19:31.183075+00	0	0	1906	1282	0	20	58	125	10	1	0	ok
743	2026-07-31 21:20:31.183376+00	0	0	1906	1282	0	20	58	126	10	1	0	ok
744	2026-07-31 21:21:31.184529+00	0	0	1906	1272	0	20	58	126	10	1	0	ok
745	2026-07-31 21:22:31.185136+00	0	0	1906	1270	0	20	58	125	10	1	0	ok
746	2026-07-31 21:23:31.185228+00	0	0	1906	1281	0	20	58	125	10	1	0	ok
747	2026-07-31 21:24:31.186062+00	0	0	1906	1283	0	20	58	125	10	1	0	ok
748	2026-07-31 21:25:31.188671+00	0	0	1906	1282	0	20	58	125	10	1	0	ok
749	2026-07-31 21:26:31.189032+00	0	0	1906	1270	0	20	58	125	10	1	0	ok
750	2026-07-31 21:27:31.18747+00	0	0	1906	1283	0	20	58	125	10	1	0	ok
751	2026-07-31 21:28:31.188593+00	0	0	1906	1267	0	20	58	125	10	1	0	ok
752	2026-07-31 21:29:31.190814+00	0	0	1906	1277	0	20	58	125	10	1	0	ok
753	2026-07-31 21:30:31.193434+00	0	0	1906	1273	0	20	58	125	10	1	0	ok
754	2026-07-31 21:31:31.192104+00	0	0	1906	1286	0	20	58	125	10	1	0	ok
755	2026-07-31 21:32:31.191805+00	0	0	1906	1279	0	20	58	125	10	1	0	ok
756	2026-07-31 21:33:31.190601+00	0	0	1906	1279	0	20	58	125	10	1	0	ok
757	2026-07-31 21:34:31.192906+00	0	0	1906	1281	0	20	58	125	10	1	0	ok
758	2026-07-31 21:35:31.190922+00	0	0	1906	1281	0	20	58	125	10	1	0	ok
759	2026-07-31 21:36:31.192296+00	0	0	1906	1271	0	20	58	126	10	1	0	ok
760	2026-07-31 21:37:31.190641+00	0	0	1906	1266	0	20	58	125	10	1	0	ok
761	2026-07-31 21:38:31.192647+00	0.19	0	1906	1271	0	20	58	125	10	1	0	ok
762	2026-07-31 21:39:31.193423+00	0.51	0	1906	1276	0	20	58	126	10	1	0	ok
763	2026-07-31 21:40:31.192289+00	0.46	0	1906	1280	0	20	58	125	10	1	0	ok
764	2026-07-31 21:41:31.190796+00	0.25	0	1906	1279	0	20	58	125	10	1	0	ok
765	2026-07-31 21:42:31.191287+00	0.09	0	1906	1272	0	20	58	126	10	1	0	ok
766	2026-07-31 21:43:31.191712+00	0.03	0	1906	1283	0	20	58	125	10	1	0	ok
767	2026-07-31 21:44:31.191539+00	0.01	0	1906	1281	0	20	58	126	11	1	0	ok
768	2026-07-31 21:45:31.191082+00	0	0	1906	1291	0	20	58	125	11	1	0	ok
769	2026-07-31 21:46:31.192602+00	0	0	1906	1283	0	20	58	125	11	1	0	ok
770	2026-07-31 21:47:31.193607+00	0.06	0	1906	1294	0	20	58	125	11	1	0	ok
771	2026-07-31 21:48:31.195548+00	0.26	0	1906	1273	0	20	58	125	11	1	0	ok
772	2026-07-31 21:49:31.194847+00	0.09	0	1906	1273	0	20	58	126	11	1	0	ok
773	2026-07-31 21:50:31.195483+00	0.03	0	1906	1280	0	20	58	125	11	1	0	ok
774	2026-07-31 21:51:31.196755+00	0.01	0	1906	1277	0	20	58	125	11	1	0	ok
775	2026-07-31 21:52:31.195529+00	0	0	1906	1276	0	20	58	126	11	1	0	ok
776	2026-07-31 21:53:31.197235+00	0	0	1906	1280	0	20	58	126	11	1	0	ok
777	2026-07-31 21:54:31.196333+00	0	0.5	1906	1277	0	20	58	125	11	1	0	ok
778	2026-07-31 21:55:31.196741+00	0	0	1906	1272	0	20	58	126	11	1	0	ok
779	2026-07-31 21:56:31.197498+00	0.34	0	1906	1276	0	20	58	125	11	1	0	ok
780	2026-07-31 21:57:31.197157+00	0.12	0.5	1906	1267	0	20	58	125	11	1	0	ok
781	2026-07-31 21:58:31.19784+00	0.04	0	1906	1264	0	20	58	125	11	1	0	ok
782	2026-07-31 21:59:31.19794+00	0.01	0.51	1906	1272	0	20	58	125	11	1	0	ok
783	2026-07-31 22:00:31.197647+00	0.54	0	1906	1274	0	20	58	125	11	1	0	ok
784	2026-07-31 22:01:31.197661+00	0.2	0	1906	1277	0	20	58	125	11	1	0	ok
785	2026-07-31 22:02:31.198665+00	0.07	0	1906	1282	0	20	58	125	11	1	0	ok
786	2026-07-31 22:03:31.199731+00	0.02	0	1906	1278	0	20	58	126	15	1	0	ok
787	2026-07-31 22:04:31.199646+00	0.44	0	1906	1275	0	20	58	125	11	1	0	ok
788	2026-07-31 22:05:31.199894+00	0.16	0.5	1906	1281	0	20	58	126	11	1	0	ok
789	2026-07-31 22:06:31.200784+00	0.3	0	1906	1275	0	20	58	126	11	1	0	ok
790	2026-07-31 22:07:31.202177+00	0.35	0	1906	1283	0	20	58	125	11	1	0	ok
791	2026-07-31 22:08:31.202454+00	0.14	0	1906	1281	0	20	58	126	11	1	0	ok
792	2026-07-31 22:09:31.20266+00	0.08	0	1906	1273	0	20	58	126	11	1	0	ok
793	2026-07-31 22:10:31.204258+00	0.06	0	1906	1276	0	20	58	126	11	1	0	ok
794	2026-07-31 22:11:31.205052+00	0.02	0	1906	1283	0	20	58	126	11	1	0	ok
795	2026-07-31 22:12:31.206939+00	0.05	0	1906	1273	0	20	58	126	11	1	0	ok
796	2026-07-31 22:13:31.205175+00	0.02	0	1906	1278	0	20	58	125	11	1	0	ok
797	2026-07-31 22:14:12.156386+00	0.01	0	1906	1336	0	20	58	99	12	1	0	ok
798	2026-07-31 22:15:12.156326+00	0	0	1906	1317	0	20	58	85	16	1	0	ok
799	2026-07-31 22:16:12.157179+00	0.47	0	1906	1312	0	20	58	87	17	1	0	ok
800	2026-07-31 22:17:12.154876+00	0.17	0	1906	1313	0	20	58	88	16	1	0	ok
801	2026-07-31 22:18:12.161423+00	0.06	0	1906	1304	0	20	58	92	17	1	0	ok
802	2026-07-31 22:19:12.161941+00	0.02	0	1906	1302	0	20	58	92	17	1	0	ok
803	2026-07-31 22:20:12.164361+00	0.01	0	1906	1301	0	20	58	93	19	1	0	ok
804	2026-07-31 22:21:12.163752+00	0.08	0	1906	1297	0	20	58	94	18	1	0	ok
805	2026-07-31 22:22:12.165563+00	0.37	0	1906	1301	0	20	58	96	19	1	0	ok
806	2026-07-31 22:23:12.166383+00	0.13	0	1906	1293	0	20	58	98	17	1	0	ok
807	2026-07-31 22:24:12.170761+00	0.05	0	1906	1300	0	20	58	98	19	1	0	ok
808	2026-07-31 22:25:12.166789+00	0.22	0	1906	1294	0	20	58	98	18	1	0	ok
809	2026-07-31 22:26:12.167227+00	0.08	0	1906	1303	0	20	58	99	19	1	0	ok
810	2026-07-31 22:27:12.168879+00	0.03	0	1906	1296	0	20	58	101	18	1	0	ok
811	2026-07-31 22:28:12.169342+00	0.01	0	1906	1296	0	20	58	100	19	1	0	ok
812	2026-07-31 22:29:12.169996+00	0.61	0	1906	1306	0	20	58	93	18	1	0	ok
813	2026-07-31 22:30:12.171807+00	0.22	0	1906	1295	0	20	58	95	19	1	0	ok
814	2026-07-31 22:31:12.172398+00	0.08	0	1906	1293	0	20	58	95	18	1	0	ok
815	2026-07-31 22:32:12.173643+00	0.06	0	1906	1301	0	20	58	96	19	1	0	ok
816	2026-07-31 22:33:12.173718+00	0.13	0	1906	1298	0	20	58	97	18	1	0	ok
817	2026-07-31 22:34:12.173831+00	0.2	0	1906	1283	0	20	58	98	19	1	0	ok
818	2026-07-31 22:35:12.17416+00	0.34	0	1906	1279	0	20	58	98	18	1	0	ok
819	2026-07-31 22:36:12.174369+00	0.12	0	1906	1287	0	20	58	99	19	1	0	ok
820	2026-07-31 22:37:12.17455+00	0.45	0	1906	1270	0	20	58	100	18	1	0	ok
821	2026-07-31 22:38:12.177129+00	0.16	0	1906	1269	0	20	58	101	19	1	0	ok
822	2026-07-31 22:39:12.178989+00	0.06	0	1906	1277	0	20	58	101	18	1	0	ok
823	2026-07-31 22:40:12.178687+00	0.76	0	1906	1278	0	20	58	101	19	1	0	ok
824	2026-07-31 22:41:12.189367+00	0.62	0	1906	1280	0	20	58	102	18	1	0	ok
825	2026-07-31 22:42:12.18031+00	0.56	0	1906	1285	0	20	58	102	16	1	0	ok
826	2026-07-31 22:43:12.180982+00	0.51	0	1906	1279	0	20	58	102	17	1	0	ok
827	2026-07-31 22:44:12.180059+00	0.53	0	1906	1283	0	20	58	103	14	1	0	ok
828	2026-07-31 22:45:12.182167+00	0.19	0	1906	1281	0	20	58	101	18	1	0	ok
829	2026-07-31 22:46:12.182897+00	0.34	0	1906	1283	0	20	58	102	18	1	0	ok
830	2026-07-31 22:47:12.182189+00	0.53	0	1906	1284	0	20	58	102	17	1	0	ok
831	2026-07-31 22:48:12.181487+00	0.23	0	1906	1282	0	20	58	102	18	1	0	ok
832	2026-07-31 22:49:12.182447+00	0.15	0	1906	1277	0	20	58	102	18	1	0	ok
833	2026-07-31 22:50:12.180642+00	0.5	0	1906	1281	0	20	58	102	19	1	0	ok
834	2026-07-31 22:51:12.182911+00	0.32	0	1906	1287	0	20	58	102	18	1	0	ok
835	2026-07-31 22:52:12.181873+00	0.39	0	1906	1284	0	20	58	102	17	1	0	ok
836	2026-07-31 22:53:12.182056+00	0.53	0	1906	1284	0	20	58	103	18	1	0	ok
837	2026-07-31 22:54:12.181395+00	0.19	0	1906	1284	0	20	58	102	18	1	0	ok
838	2026-07-31 22:55:12.180895+00	0.14	0	1906	1277	0	20	58	102	18	1	0	ok
839	2026-07-31 22:56:12.181664+00	0.43	0	1906	1268	0	20	58	103	19	1	0	ok
840	2026-07-31 22:57:12.180955+00	0.16	0	1906	1279	0	20	58	103	17	1	0	ok
841	2026-07-31 22:58:12.182861+00	0.46	0	1906	1284	0	20	58	102	18	1	0	ok
842	2026-07-31 22:59:12.183662+00	0.17	0	1906	1273	0	20	58	102	17	1	0	ok
843	2026-07-31 23:00:12.182043+00	0.06	0	1906	1269	0	20	58	102	17	1	0	ok
844	2026-07-31 23:01:12.183288+00	0.22	0	1906	1270	0	20	58	103	18	1	0	ok
845	2026-07-31 23:02:12.183339+00	0.08	0	1906	1268	0	20	58	103	19	1	0	ok
846	2026-07-31 23:03:12.18267+00	0.03	0	1906	1272	0	20	58	102	17	1	0	ok
847	2026-07-31 23:04:12.183631+00	0.41	0	1906	1273	0	20	58	102	19	1	0	ok
848	2026-07-31 23:05:12.184297+00	0.76	0	1906	1269	0	20	58	103	17	1	0	ok
849	2026-07-31 23:06:12.184162+00	0.35	0	1906	1273	0	20	58	102	19	1	0	ok
850	2026-07-31 23:07:12.183814+00	0.53	0	1906	1275	0	20	58	102	17	1	0	ok
851	2026-07-31 23:08:12.185276+00	0.33	0	1906	1275	0	20	58	102	19	1	0	ok
852	2026-07-31 23:09:12.184115+00	0.23	0	1906	1286	0	20	58	103	17	1	0	ok
853	2026-07-31 23:10:12.185706+00	0.56	0	1906	1273	0	20	58	103	19	1	0	ok
854	2026-07-31 23:11:12.185247+00	0.27	0	1906	1274	0	20	58	102	18	1	0	ok
855	2026-07-31 23:12:12.186293+00	0.44	0	1906	1274	0	20	58	103	19	1	0	ok
856	2026-07-31 23:13:12.185913+00	0.5	0	1906	1285	0	20	58	103	18	1	0	ok
857	2026-07-31 23:14:12.185146+00	0.25	0	1906	1280	0	20	58	103	19	1	0	ok
858	2026-07-31 23:15:12.184681+00	0.43	0	1906	1281	0	20	58	103	18	1	0	ok
859	2026-07-31 23:16:12.185465+00	0.29	0	1906	1282	0	20	58	102	19	1	0	ok
860	2026-07-31 23:17:12.187201+00	0.24	0.5	1906	1282	0	20	58	102	18	1	0	ok
861	2026-07-31 23:18:12.186756+00	0.43	0	1906	1289	0	20	58	103	17	1	0	ok
862	2026-07-31 23:19:12.187296+00	0.22	0	1906	1279	0	20	58	102	18	1	0	ok
863	2026-07-31 23:20:12.187469+00	0.15	0	1906	1281	0	20	58	102	19	1	0	ok
864	2026-07-31 23:21:12.186426+00	0.53	0	1906	1278	0	20	58	103	18	1	0	ok
865	2026-07-31 23:22:12.188298+00	0.53	0.5	1906	1283	0	20	58	102	19	1	0	ok
866	2026-07-31 23:23:12.187107+00	0.53	0	1906	1283	0	20	58	103	18	1	0	ok
867	2026-07-31 23:24:12.187464+00	0.53	0	1906	1277	0	20	58	103	19	1	0	ok
868	2026-07-31 23:25:12.186693+00	0.4	0	1906	1275	0	20	58	103	18	1	0	ok
869	2026-07-31 23:26:12.186868+00	0.41	0	1906	1279	0	20	58	103	19	1	0	ok
870	2026-07-31 23:27:12.187112+00	0.49	0	1906	1284	0	20	58	103	18	1	0	ok
871	2026-07-31 23:28:12.188967+00	0.59	0	1906	1275	0	20	58	104	19	1	0	ok
872	2026-07-31 23:29:12.187961+00	0.55	0	1906	1278	0	20	58	103	18	1	0	ok
873	2026-07-31 23:30:12.187273+00	0.73	0	1906	1278	0	20	58	103	19	1	0	ok
874	2026-07-31 23:31:12.187453+00	0.73	0	1906	1275	0	20	58	104	18	1	0	ok
875	2026-07-31 23:32:12.187304+00	0.67	0	1906	1278	0	20	58	103	19	1	0	ok
876	2026-07-31 23:33:12.186422+00	0.61	0	1906	1279	0	20	58	103	18	1	0	ok
877	2026-07-31 23:34:12.219246+00	0.59	0	1906	1273	0	20	58	103	19	1	0	ok
878	2026-07-31 23:35:12.188236+00	0.78	0	1906	1279	0	20	58	103	18	1	0	ok
879	2026-07-31 23:36:12.187779+00	0.65	0	1906	1282	0	20	58	103	19	1	0	ok
880	2026-07-31 23:37:12.188902+00	0.31	0	1906	1272	0	20	58	103	18	1	0	ok
881	2026-07-31 23:38:12.188597+00	0.33	0	1906	1273	0	20	58	103	19	1	0	ok
882	2026-07-31 23:39:12.189932+00	0.49	0	1906	1272	0	20	58	103	18	1	0	ok
883	2026-07-31 23:40:12.191567+00	0.25	0	1906	1270	0	20	58	103	19	1	0	ok
884	2026-07-31 23:41:12.189958+00	0.24	0	1906	1282	0	20	58	103	18	1	0	ok
885	2026-07-31 23:42:12.190691+00	0.45	0	1906	1275	0	20	58	103	19	1	0	ok
886	2026-07-31 23:43:12.19087+00	0.24	0	1906	1276	0	20	58	103	18	1	0	ok
887	2026-07-31 23:44:12.191048+00	0.16	0	1906	1278	0	20	58	103	19	1	0	ok
888	2026-07-31 23:45:12.192218+00	0.2	0	1906	1278	0	20	58	101	18	1	0	ok
889	2026-07-31 23:46:12.190994+00	0.15	0	1906	1279	0	20	58	102	19	1	0	ok
890	2026-07-31 23:47:12.190159+00	0.13	0	1906	1281	0	20	58	102	16	1	0	ok
891	2026-07-31 23:48:12.191045+00	0.12	0	1906	1278	0	20	58	103	19	1	0	ok
892	2026-07-31 23:49:12.193332+00	0.56	0	1906	1281	0	20	58	103	18	1	0	ok
893	2026-07-31 23:50:12.193447+00	0.33	0	1906	1280	0	20	58	103	19	1	0	ok
894	2026-07-31 23:51:12.191624+00	0.2	0	1906	1267	0	20	58	103	18	1	0	ok
895	2026-07-31 23:52:12.193881+00	0.14	0	1906	1282	0	20	58	103	17	1	0	ok
896	2026-07-31 23:53:12.194034+00	0.42	0	1906	1276	0	20	58	103	18	1	0	ok
897	2026-07-31 23:54:12.194226+00	0.37	0.5	1906	1277	0	20	58	103	19	1	0	ok
898	2026-07-31 23:55:12.196232+00	0.2	0	1906	1277	0	20	58	103	18	1	0	ok
899	2026-07-31 23:56:12.198141+00	0.22	0	1906	1277	0	20	58	103	19	1	0	ok
900	2026-07-31 23:57:12.196068+00	0.3	0	1906	1277	0	20	58	103	18	1	0	ok
901	2026-07-31 23:58:12.19688+00	0.26	0	1906	1274	0	20	58	103	19	1	0	ok
902	2026-07-31 23:59:12.199618+00	0.17	0	1906	1277	0	20	58	103	18	1	0	ok
903	2026-08-01 00:00:12.200459+00	0.06	0	1906	1261	0	20	57	103	19	1	0	ok
904	2026-08-01 00:01:12.199924+00	0.24	0	1906	1262	0	20	57	103	18	1	0	ok
905	2026-08-01 00:02:12.202358+00	0.16	0	1906	1257	0	20	57	103	19	1	0	ok
906	2026-08-01 00:03:12.20085+00	0.13	0	1906	1259	0	20	57	103	18	1	0	ok
907	2026-08-01 00:04:12.200864+00	0.19	0	1906	1261	0	20	57	103	17	1	0	ok
908	2026-08-01 00:05:12.200996+00	0.14	0	1906	1262	0	20	57	103	18	1	0	ok
909	2026-08-01 00:06:12.201861+00	0.49	0	1906	1260	0	20	57	103	19	1	0	ok
910	2026-08-01 00:07:12.202797+00	0.25	0	1906	1265	0	20	57	104	18	1	0	ok
911	2026-08-01 00:08:12.204685+00	0.17	0	1906	1261	0	20	57	104	19	1	0	ok
912	2026-08-01 00:09:12.20423+00	0.13	0	1906	1262	0	20	57	103	18	1	0	ok
913	2026-08-01 00:10:12.204715+00	0.64	0	1906	1264	0	20	57	104	17	1	0	ok
914	2026-08-01 00:11:12.205088+00	0.38	0	1906	1271	0	20	57	104	18	1	0	ok
915	2026-08-01 00:12:12.205244+00	0.14	0	1906	1270	0	20	57	103	16	1	0	ok
916	2026-08-01 00:13:12.206106+00	0.05	0	1906	1265	0	20	57	103	18	1	0	ok
917	2026-08-01 00:14:12.207909+00	0.16	0	1906	1265	0	20	57	104	18	1	0	ok
918	2026-08-01 00:15:12.209894+00	0.13	0	1906	1264	0	20	57	104	16	1	0	ok
919	2026-08-01 00:16:12.209222+00	0.12	0.5	1906	1257	0	20	57	104	19	1	0	ok
920	2026-08-01 00:17:12.208815+00	0.12	0	1906	1258	0	20	57	104	17	1	0	ok
921	2026-08-01 00:18:12.210446+00	0.11	0.5	1906	1272	0	20	57	104	13	1	0	ok
922	2026-08-01 00:19:12.211448+00	0.16	0.5	1906	1266	0	20	57	104	13	1	0	ok
923	2026-08-01 00:20:12.211654+00	0.35	0	1906	1269	0	20	57	104	14	1	0	ok
924	2026-08-01 00:21:12.210598+00	0.2	0	1906	1270	0	20	57	104	13	1	0	ok
925	2026-08-01 00:22:12.211829+00	0.15	0	1906	1269	0	20	57	105	13	1	0	ok
926	2026-08-01 00:23:12.21307+00	0.13	0	1906	1273	0	20	57	105	12	1	0	ok
927	2026-08-01 00:24:12.212163+00	0.19	0	1906	1274	0	20	57	104	13	1	0	ok
928	2026-08-01 00:25:12.213384+00	0.29	0	1906	1270	0	20	57	104	12	1	0	ok
929	2026-08-01 00:26:12.212885+00	0.25	0	1906	1274	0	20	57	104	12	1	0	ok
930	2026-08-01 00:27:12.212402+00	0.16	0	1906	1272	0	20	57	104	13	1	0	ok
931	2026-08-01 00:28:12.213396+00	0.13	0	1906	1265	0	20	57	105	12	1	0	ok
932	2026-08-01 00:29:12.212585+00	0.12	0	1906	1270	0	20	57	104	13	1	0	ok
933	2026-08-01 00:30:12.212586+00	0.34	0	1906	1269	0	20	57	104	14	1	0	ok
934	2026-08-01 00:31:12.213415+00	0.2	0	1906	1263	0	20	57	104	17	1	0	ok
935	2026-08-01 00:32:12.21379+00	0.14	0	1906	1263	0	20	57	104	15	1	0	ok
936	2026-08-01 00:33:12.213517+00	0.13	0	1906	1269	0	20	57	104	15	1	0	ok
937	2026-08-01 00:34:12.216074+00	0.12	0.5	1906	1261	0	20	57	104	16	1	0	ok
938	2026-08-01 00:35:12.215073+00	0.12	0	1906	1267	0	20	57	104	16	1	0	ok
939	2026-08-01 00:36:12.214567+00	0.11	0	1906	1264	0	20	57	104	16	1	0	ok
940	2026-08-01 00:37:12.214638+00	0.11	0	1906	1274	0	20	57	104	16	1	0	ok
941	2026-08-01 00:38:12.21447+00	0.11	0.5	1906	1264	0	20	57	104	16	1	0	ok
942	2026-08-01 00:39:12.215816+00	0.11	0	1906	1266	0	20	57	104	15	1	0	ok
943	2026-08-01 00:40:12.218478+00	0.11	0	1906	1270	0	20	57	104	16	1	0	ok
944	2026-08-01 00:41:12.215902+00	0.11	0	1906	1277	0	20	57	104	13	1	0	ok
945	2026-08-01 00:42:12.237897+00	0.11	0	1906	1261	0	20	57	104	13	1	0	ok
946	2026-08-01 00:43:12.217657+00	0.11	0	1906	1277	0	20	57	96	13	1	0	ok
947	2026-08-01 00:44:12.216916+00	0.11	0	1906	1274	0	20	57	97	14	1	0	ok
948	2026-08-01 00:45:12.216165+00	0.15	0	1906	1273	0	20	57	98	13	1	0	ok
949	2026-08-01 00:46:12.219664+00	0.05	0	1906	1262	0	20	57	99	17	1	0	ok
950	2026-08-01 00:47:12.221614+00	0.24	0	1906	1266	0	20	57	99	17	1	0	ok
951	2026-08-01 00:48:12.221125+00	0.16	0	1906	1263	0	20	57	100	17	1	0	ok
952	2026-08-01 00:49:12.219924+00	0.19	0	1906	1262	0	20	57	100	17	1	0	ok
953	2026-08-01 00:50:12.221633+00	0.14	0	1906	1264	0	20	57	102	17	1	0	ok
954	2026-08-01 00:51:12.220601+00	0.12	0	1906	1268	0	20	57	102	17	1	0	ok
955	2026-08-01 00:52:12.22216+00	0.17	0.5	1906	1267	0	20	57	103	17	1	0	ok
956	2026-08-01 00:53:12.221419+00	0.14	0	1906	1266	0	20	57	103	17	1	0	ok
957	2026-08-01 00:54:12.222228+00	0.12	0	1906	1268	0	20	57	103	17	1	0	ok
958	2026-08-01 00:55:12.222321+00	0.12	0	1906	1256	0	20	57	103	17	1	0	ok
959	2026-08-01 00:56:12.223484+00	0.19	0	1906	1261	0	20	57	103	16	1	0	ok
960	2026-08-01 00:57:12.222449+00	0.14	0	1906	1263	0	20	57	104	15	1	0	ok
961	2026-08-01 00:58:12.22505+00	0.2	0.5	1906	1258	0	20	57	104	16	1	0	ok
962	2026-08-01 00:59:12.223252+00	0.14	0	1906	1257	0	20	57	103	17	1	0	ok
963	2026-08-01 01:00:12.223322+00	0.13	0	1906	1265	0	20	57	103	17	1	0	ok
964	2026-08-01 01:01:12.223632+00	0.12	0	1906	1261	0	20	57	104	17	1	0	ok
965	2026-08-01 01:02:12.226289+00	0.12	0	1906	1257	0	20	57	103	19	1	0	ok
966	2026-08-01 01:03:12.225482+00	0.11	0	1906	1263	0	20	57	103	18	1	0	ok
967	2026-08-01 01:04:12.226354+00	0.11	0	1906	1256	0	20	57	104	19	1	0	ok
968	2026-08-01 01:05:12.225023+00	0.11	0	1906	1262	0	20	57	104	18	1	0	ok
969	2026-08-01 01:06:12.22452+00	0.11	0	1906	1262	0	20	57	104	19	1	0	ok
970	2026-08-01 01:07:12.22447+00	0.11	0	1906	1258	0	20	57	104	18	1	0	ok
971	2026-08-01 01:08:12.225344+00	0.11	0	1906	1259	0	20	57	105	19	1	0	ok
972	2026-08-01 01:09:12.223769+00	0.11	0	1906	1265	0	20	57	104	18	1	0	ok
973	2026-08-01 01:10:12.224968+00	0.11	0	1906	1258	0	20	57	105	19	1	0	ok
974	2026-08-01 01:11:12.226422+00	0.11	0	1906	1263	0	20	57	105	18	1	0	ok
975	2026-08-01 01:12:12.231125+00	0.11	0	1906	1253	0	20	57	104	19	1	0	ok
976	2026-08-01 01:13:12.228091+00	0.11	0	1906	1264	0	20	57	104	18	1	0	ok
977	2026-08-01 01:14:12.227965+00	0.41	0	1906	1263	0	20	57	105	19	1	0	ok
978	2026-08-01 01:15:12.226814+00	0.22	0	1906	1262	0	20	57	105	16	1	0	ok
979	2026-08-01 01:16:12.230313+00	0.08	0	1906	1258	0	20	57	106	19	1	0	ok
980	2026-08-01 01:17:12.229446+00	0.1	0	1906	1254	0	20	57	105	18	1	0	ok
981	2026-08-01 01:18:12.230332+00	0.11	0.5	1906	1258	0	20	57	105	19	1	0	ok
982	2026-08-01 01:19:12.230845+00	0.04	0	1906	1263	0	20	57	105	12	1	0	ok
983	2026-08-01 01:20:12.231562+00	0.09	0	1906	1264	0	20	57	105	19	1	0	ok
984	2026-08-01 01:21:12.231886+00	0.1	0	1906	1258	0	20	57	105	15	1	0	ok
985	2026-08-01 01:22:12.234459+00	0.11	0	1906	1258	0	20	57	106	19	1	0	ok
986	2026-08-01 01:23:12.232929+00	0.19	0	1906	1258	0	20	57	105	18	1	0	ok
987	2026-08-01 01:24:12.236563+00	0.14	0	1906	1255	0	20	57	105	19	1	0	ok
988	2026-08-01 01:25:12.235792+00	0.12	0	1906	1254	0	20	57	105	18	1	0	ok
989	2026-08-01 01:26:12.236227+00	0.12	0	1906	1256	0	20	57	105	19	1	0	ok
990	2026-08-01 01:27:12.238529+00	0.16	0	1906	1256	0	20	57	105	18	1	0	ok
991	2026-08-01 01:28:12.241701+00	0.13	0	1906	1255	0	20	57	105	19	1	0	ok
992	2026-08-01 01:29:12.240439+00	0.05	0	1906	1254	0	20	57	105	18	1	0	ok
993	2026-08-01 01:30:12.243261+00	0.16	0	1906	1252	0	20	57	105	19	1	0	ok
994	2026-08-01 01:31:12.243563+00	0.06	0.5	1906	1255	0	20	57	105	18	1	0	ok
995	2026-08-01 01:32:12.243099+00	0.02	0.5	1906	1262	0	20	57	105	15	1	0	ok
996	2026-08-01 01:33:12.242922+00	0	0	1906	1260	0	20	57	105	16	1	0	ok
997	2026-08-01 01:34:12.244055+00	0.07	0	1906	1260	0	20	57	105	16	1	0	ok
998	2026-08-01 01:35:12.244915+00	0.02	0	1906	1265	0	20	57	105	16	1	0	ok
999	2026-08-01 01:36:12.244237+00	0.08	0	1906	1254	0	20	56	106	21	1	0	ok
1000	2026-08-01 01:37:12.2435+00	0.03	0	1906	1253	0	20	56	105	21	1	0	ok
1001	2026-08-01 01:38:12.243445+00	0.08	0	1906	1267	0	20	56	105	16	1	0	ok
1002	2026-08-01 01:39:12.245369+00	0.1	0	1906	1263	0	20	56	105	15	1	0	ok
1003	2026-08-01 01:40:12.245665+00	0.2	0	1906	1263	0	20	56	105	18	1	0	ok
1004	2026-08-01 01:41:12.247059+00	0.2	0	1906	1251	0	20	56	105	18	1	0	ok
1005	2026-08-01 01:42:12.246045+00	0.07	0	1906	1256	0	20	56	106	16	1	0	ok
1006	2026-08-01 01:43:12.247241+00	0.02	0	1906	1264	0	20	56	105	18	1	0	ok
1007	2026-08-01 01:44:12.248272+00	0.01	0	1906	1254	0	20	56	106	15	1	0	ok
1008	2026-08-01 01:45:12.246103+00	0.07	0	1906	1250	0	20	56	105	18	1	0	ok
1009	2026-08-01 01:46:12.24591+00	0.03	0	1906	1259	0	20	56	105	18	1	0	ok
1010	2026-08-01 01:47:12.246382+00	0.01	0	1906	1259	0	20	56	106	17	1	0	ok
1011	2026-08-01 01:48:12.246008+00	0.07	0	1906	1249	0	20	56	105	18	1	0	ok
1012	2026-08-01 01:49:12.24645+00	0.09	0	1906	1250	0	20	56	105	14	1	0	ok
1013	2026-08-01 01:50:12.247681+00	0.11	0	1906	1263	0	20	56	107	17	1	0	ok
1014	2026-08-01 01:51:12.2469+00	0.04	0	1906	1261	0	20	56	105	14	1	0	ok
1015	2026-08-01 01:52:12.246514+00	0.01	0	1906	1253	0	20	56	105	17	1	0	ok
1016	2026-08-01 01:53:12.247557+00	0	0	1906	1257	0	20	56	106	18	1	0	ok
1017	2026-08-01 01:54:12.247041+00	0.07	0	1906	1253	0	20	56	106	17	1	0	ok
1018	2026-08-01 01:55:12.24737+00	0.1	0	1906	1251	0	20	56	106	18	1	0	ok
1019	2026-08-01 01:56:12.249387+00	0.11	0	1906	1250	0	20	56	106	19	1	0	ok
1020	2026-08-01 01:57:12.248283+00	0.21	0	1906	1231	0	20	56	106	16	1	0	ok
1021	2026-08-01 01:58:12.249806+00	0.16	0	1906	1225	0	20	56	106	19	1	0	ok
1022	2026-08-01 01:59:12.250497+00	0.06	0	1906	1233	0	20	56	105	16	1	0	ok
1023	2026-08-01 02:00:12.249764+00	0.09	0	1906	1222	0	20	56	105	19	1	0	ok
1024	2026-08-01 02:01:12.248885+00	0.03	0	1906	1221	0	20	57	106	18	1	0	ok
1025	2026-08-01 02:02:12.250348+00	0.01	0	1906	1235	0	20	57	105	19	1	0	ok
1026	2026-08-01 02:03:12.250186+00	0	0	1906	1222	0	20	57	106	18	1	0	ok
1027	2026-08-01 02:04:12.250089+00	0	0	1906	1233	0	20	57	106	19	1	0	ok
1028	2026-08-01 02:05:12.250173+00	0.07	0	1906	1220	0	20	57	106	16	1	0	ok
1029	2026-08-01 02:06:12.253158+00	0.02	0	1906	1223	0	20	57	105	18	1	0	ok
1030	2026-08-01 02:07:12.252107+00	0.01	0	1906	1222	0	20	57	106	19	1	0	ok
1031	2026-08-01 02:08:12.253762+00	0	0	1906	1221	0	20	57	105	20	1	0	ok
1032	2026-08-01 02:09:12.259292+00	0.07	0	1906	1234	0	20	57	106	17	1	0	ok
1033	2026-08-01 02:10:12.255803+00	0.02	0.5	1906	1227	0	20	57	106	19	1	0	ok
1034	2026-08-01 02:11:12.257202+00	0.01	0	1906	1228	0	20	57	106	18	1	0	ok
1035	2026-08-01 02:12:12.258272+00	0	0	1906	1223	0	20	57	105	19	1	0	ok
1036	2026-08-01 02:13:12.257067+00	0	0	1906	1231	0	20	57	106	18	1	0	ok
1037	2026-08-01 02:14:12.257985+00	0.07	0.5	1906	1235	0	20	57	106	18	1	0	ok
1038	2026-08-01 02:15:12.257412+00	0.02	0	1906	1246	0	20	57	106	18	1	0	ok
1039	2026-08-01 02:16:12.265102+00	0.01	0	1906	1232	0	20	57	106	19	1	0	ok
1040	2026-08-01 02:17:12.259712+00	0	0	1906	1229	0	20	57	106	18	1	0	ok
1041	2026-08-01 02:18:12.260989+00	0.07	0	1906	1234	0	20	57	106	19	1	0	ok
1042	2026-08-01 02:19:12.262141+00	0.02	0	1906	1234	0	20	57	106	18	1	0	ok
1043	2026-08-01 02:20:12.262495+00	0.01	0	1906	1236	0	20	57	106	18	1	0	ok
1044	2026-08-01 02:21:12.260578+00	0	0	1906	1230	0	20	57	106	16	1	0	ok
1045	2026-08-01 02:22:12.262532+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1046	2026-08-01 02:23:12.264887+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1047	2026-08-01 02:24:12.266507+00	0	0	1906	1231	0	20	57	106	20	1	0	ok
1048	2026-08-01 02:25:12.264102+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1049	2026-08-01 02:26:12.265036+00	0	0	1906	1234	0	20	57	106	17	1	0	ok
1050	2026-08-01 02:27:12.266447+00	0	0.5	1906	1236	0	20	57	106	18	1	0	ok
1051	2026-08-01 02:28:12.266872+00	0	0	1906	1231	0	20	57	106	19	1	0	ok
1052	2026-08-01 02:29:12.267163+00	0	0	1906	1233	0	20	57	106	18	1	0	ok
1053	2026-08-01 02:30:12.270461+00	0.07	0	1906	1233	0	20	57	106	19	1	0	ok
1054	2026-08-01 02:31:12.269238+00	0.02	0	1906	1222	0	20	57	106	18	1	0	ok
1055	2026-08-01 02:32:12.268246+00	0.01	0	1906	1235	0	20	57	107	19	1	0	ok
1056	2026-08-01 02:33:12.270433+00	0	0	1906	1231	0	20	57	106	18	1	0	ok
1057	2026-08-01 02:34:12.272126+00	0	0	1906	1231	0	20	57	106	19	1	0	ok
1058	2026-08-01 02:35:12.27152+00	0	0	1906	1235	0	20	57	106	18	1	0	ok
1059	2026-08-01 02:36:12.270508+00	0	0	1906	1220	0	20	57	107	19	1	0	ok
1060	2026-08-01 02:37:12.271551+00	0	0	1906	1221	0	20	57	107	18	1	0	ok
1061	2026-08-01 02:38:12.273606+00	0	0	1906	1222	0	20	57	106	19	1	0	ok
1062	2026-08-01 02:39:12.27137+00	0	0	1906	1227	0	20	57	106	16	1	0	ok
1063	2026-08-01 02:40:12.275623+00	0	0	1906	1219	0	20	57	106	18	1	0	ok
1064	2026-08-01 02:41:12.274158+00	0	0	1906	1224	0	20	57	106	19	1	0	ok
1065	2026-08-01 02:42:12.273954+00	0	0	1906	1229	0	20	57	106	20	1	0	ok
1066	2026-08-01 02:43:12.274001+00	0	0	1906	1228	0	20	57	106	19	1	0	ok
1067	2026-08-01 02:44:12.274772+00	0	0	1906	1207	0	20	57	106	20	1	0	ok
1068	2026-08-01 02:45:12.276671+00	0	0	1906	1226	0	20	57	106	19	1	0	ok
1069	2026-08-01 02:46:12.273729+00	0	0	1906	1230	0	20	57	107	19	1	0	ok
1070	2026-08-01 02:47:12.274523+00	0	0	1906	1224	0	20	57	106	18	1	0	ok
1071	2026-08-01 02:48:12.27503+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1072	2026-08-01 02:49:12.275402+00	0	0	1906	1231	0	20	57	106	17	1	0	ok
1073	2026-08-01 02:50:12.278247+00	0.06	0	1906	1248	0	20	57	107	19	1	0	ok
1074	2026-08-01 02:51:12.275327+00	0.02	0	1906	1235	0	20	57	106	18	1	0	ok
1075	2026-08-01 02:52:12.278726+00	0.01	0	1906	1229	0	20	57	107	19	1	0	ok
1076	2026-08-01 02:53:12.279761+00	0	0	1906	1235	0	20	57	107	18	1	0	ok
1077	2026-08-01 02:54:12.281078+00	0	0	1906	1233	0	20	57	107	19	1	0	ok
1078	2026-08-01 02:55:12.282103+00	0	0	1906	1227	0	20	57	106	18	1	0	ok
1079	2026-08-01 02:56:12.282715+00	0	0	1906	1237	0	20	57	108	12	1	0	ok
1080	2026-08-01 02:57:12.281774+00	0	0	1906	1245	0	20	57	106	12	1	0	ok
1081	2026-08-01 02:58:12.283482+00	0	0	1906	1238	0	20	57	107	12	1	0	ok
1082	2026-08-01 02:59:12.284712+00	0	0	1906	1246	0	20	57	106	10	1	0	ok
1083	2026-08-01 03:00:12.283809+00	0.07	0	1906	1240	0	20	57	107	13	1	0	ok
1084	2026-08-01 03:01:12.282982+00	0.02	0	1906	1244	0	20	57	107	13	1	0	ok
1085	2026-08-01 03:02:12.283644+00	0.01	0	1906	1233	0	20	57	107	16	1	0	ok
1086	2026-08-01 03:03:12.283284+00	0	0	1906	1245	0	20	57	107	15	1	0	ok
1087	2026-08-01 03:04:12.288143+00	0	0.5	1906	1223	0	20	57	107	17	1	0	ok
1088	2026-08-01 03:05:12.287159+00	0	0	1906	1238	0	20	57	107	18	1	0	ok
1089	2026-08-01 03:06:12.288936+00	0	0	1906	1236	0	20	57	106	18	1	0	ok
1090	2026-08-01 03:07:12.287895+00	0	0	1906	1242	0	20	57	107	15	1	0	ok
1091	2026-08-01 03:08:12.288624+00	0	0	1906	1234	0	20	57	106	18	1	0	ok
1092	2026-08-01 03:09:12.287676+00	0	0.5	1906	1255	0	20	57	107	18	1	0	ok
1093	2026-08-01 03:10:12.289954+00	0	0	1906	1245	0	20	57	107	19	1	0	ok
1094	2026-08-01 03:11:12.291132+00	0	0	1906	1249	0	20	57	107	17	1	0	ok
1095	2026-08-01 03:12:12.289783+00	0.04	0	1906	1244	0	20	57	107	19	1	0	ok
1096	2026-08-01 03:13:12.289059+00	0.01	0	1906	1253	0	20	57	107	16	1	0	ok
1097	2026-08-01 03:14:12.290737+00	0	0	1906	1244	0	20	57	107	19	1	0	ok
1098	2026-08-01 03:15:12.290866+00	0	0	1906	1247	0	20	57	107	18	1	0	ok
1099	2026-08-01 03:16:12.289942+00	0	0	1906	1253	0	20	57	107	19	1	0	ok
1100	2026-08-01 03:17:12.289539+00	0	0	1906	1250	0	20	57	107	18	1	0	ok
1101	2026-08-01 03:18:12.292412+00	0	0	1906	1253	0	20	57	107	18	1	0	ok
1102	2026-08-01 03:19:12.293109+00	0	0	1906	1257	0	20	57	107	16	1	0	ok
1103	2026-08-01 03:20:12.292144+00	0	0	1906	1256	0	20	57	107	16	1	0	ok
1104	2026-08-01 03:21:12.290699+00	0	0	1906	1246	0	20	57	107	16	1	0	ok
1105	2026-08-01 03:22:12.29099+00	0	0	1906	1251	0	20	57	107	15	1	0	ok
1106	2026-08-01 03:23:12.291152+00	0	0	1906	1256	0	20	57	107	14	1	0	ok
1107	2026-08-01 03:24:12.291382+00	0	0	1906	1245	0	20	57	107	17	1	0	ok
1108	2026-08-01 03:25:12.292876+00	0	0	1906	1255	0	20	57	107	16	1	0	ok
1109	2026-08-01 03:26:12.293118+00	0	0.5	1906	1243	0	20	57	107	16	1	0	ok
1110	2026-08-01 03:27:12.292202+00	0	0	1906	1249	0	20	57	107	17	1	0	ok
1111	2026-08-01 03:28:12.293123+00	0	0	1906	1246	0	20	57	107	18	1	0	ok
1112	2026-08-01 03:29:12.293275+00	0	0	1906	1246	0	20	57	107	17	1	0	ok
1113	2026-08-01 03:30:12.29427+00	0	0	1906	1246	0	20	57	107	18	1	0	ok
1114	2026-08-01 03:31:12.294447+00	0	0	1906	1266	0	20	57	107	16	1	0	ok
1115	2026-08-01 03:32:12.295201+00	0.06	0	1906	1251	0	20	57	107	17	1	0	ok
1116	2026-08-01 03:33:12.296308+00	0.02	0.5	1906	1253	0	20	57	107	16	1	0	ok
1117	2026-08-01 03:34:12.296402+00	0	0	1906	1252	0	20	57	107	17	1	0	ok
1118	2026-08-01 03:35:12.297612+00	0	0	1906	1247	0	20	57	107	16	1	0	ok
1119	2026-08-01 03:36:12.297782+00	0	0	1906	1253	0	20	57	107	18	1	0	ok
1120	2026-08-01 03:37:12.29723+00	0	0	1906	1250	0	20	57	107	17	1	0	ok
1121	2026-08-01 03:38:12.298641+00	0	0.5	1906	1249	0	20	57	107	18	1	0	ok
1122	2026-08-01 03:39:12.29761+00	0	0	1906	1247	0	20	57	107	17	1	0	ok
1123	2026-08-01 03:40:12.299821+00	0	0	1906	1248	0	20	57	107	19	1	0	ok
1124	2026-08-01 03:41:12.301194+00	0	0	1906	1243	0	20	57	107	18	1	0	ok
1125	2026-08-01 03:42:12.302101+00	0	0	1906	1249	0	20	57	107	19	1	0	ok
1126	2026-08-01 03:43:12.305596+00	0	0	1906	1249	0	20	57	108	18	1	0	ok
1127	2026-08-01 03:44:12.305528+00	0	0	1906	1248	0	20	57	107	19	1	0	ok
1128	2026-08-01 03:45:12.303963+00	0	0	1906	1248	0	20	57	107	17	1	0	ok
1129	2026-08-01 03:46:12.304395+00	0	0.5	1906	1247	0	20	57	106	19	1	0	ok
1130	2026-08-01 03:47:12.30427+00	0	0	1906	1249	0	20	57	106	18	1	0	ok
1131	2026-08-01 03:48:12.304427+00	0	0	1906	1249	0	20	57	106	19	1	0	ok
1132	2026-08-01 03:49:12.303644+00	0	0	1906	1250	0	20	57	106	16	1	0	ok
1133	2026-08-01 03:50:12.306368+00	0	0	1906	1229	0	20	57	106	19	1	0	ok
1134	2026-08-01 03:51:12.304828+00	0	0	1906	1246	0	20	57	106	18	1	0	ok
1135	2026-08-01 03:52:12.306237+00	0	0	1906	1247	0	20	57	106	19	1	0	ok
1136	2026-08-01 03:53:12.303855+00	0	0	1906	1244	0	20	57	106	18	1	0	ok
1137	2026-08-01 03:54:12.304956+00	0	0	1906	1245	0	20	57	106	19	1	0	ok
1138	2026-08-01 03:55:12.303228+00	0	0	1906	1252	0	20	57	106	17	1	0	ok
1139	2026-08-01 03:56:12.30478+00	0.1	0	1906	1238	0	20	57	106	18	1	0	ok
1140	2026-08-01 03:57:12.303933+00	0.03	0	1906	1241	0	20	57	106	18	1	0	ok
1141	2026-08-01 03:58:12.305266+00	0.01	0	1906	1249	0	20	57	107	19	1	0	ok
1142	2026-08-01 03:59:12.303915+00	0	0	1906	1240	0	20	57	106	18	1	0	ok
1143	2026-08-01 04:00:12.306762+00	0	0	1906	1245	0	20	57	106	19	1	0	ok
1144	2026-08-01 04:01:12.305439+00	0	0	1906	1251	0	20	57	106	15	1	0	ok
1145	2026-08-01 04:02:12.306641+00	0	0	1906	1254	0	20	57	106	16	1	0	ok
1146	2026-08-01 04:03:12.306725+00	0	0	1906	1241	0	20	57	106	14	1	0	ok
1147	2026-08-01 04:04:12.30787+00	0	0	1906	1249	0	20	57	106	17	1	0	ok
1148	2026-08-01 04:05:12.30777+00	0.68	0	1906	1247	0	20	57	106	18	1	0	ok
1149	2026-08-01 04:06:12.310492+00	0.46	0	1906	1246	0	20	57	106	19	1	0	ok
1150	2026-08-01 04:07:12.310519+00	0.17	0	1906	1247	0	20	57	106	18	1	0	ok
1151	2026-08-01 04:08:12.311479+00	0.06	0	1906	1246	0	20	57	107	18	1	0	ok
1152	2026-08-01 04:09:12.313356+00	0.02	0	1906	1248	0	20	57	106	18	1	0	ok
1153	2026-08-01 04:10:12.314678+00	0.01	0	1906	1248	0	20	57	106	19	1	0	ok
1154	2026-08-01 04:11:12.316135+00	0	0	1906	1252	0	20	57	106	17	1	0	ok
1155	2026-08-01 04:12:12.315117+00	0	0.5	1906	1249	0	20	57	107	19	1	0	ok
1156	2026-08-01 04:13:12.314273+00	0	0	1906	1254	0	20	57	106	18	1	0	ok
1157	2026-08-01 04:14:12.314387+00	0.04	0	1906	1250	0	20	57	106	19	1	0	ok
1158	2026-08-01 04:14:17.212599+00	0.12	0	1906	1291	0	20	57	99	12	1	0	ok
1159	2026-08-01 04:15:17.212508+00	0.25	0	1906	1267	0	20	57	84	16	1	0	ok
1160	2026-08-01 04:16:17.213087+00	0.09	0	1906	1261	0	20	57	87	14	1	0	ok
1161	2026-08-01 04:17:17.212882+00	0.03	0	1906	1266	0	20	57	88	14	1	0	ok
1162	2026-08-01 04:18:17.213265+00	0.06	0	1906	1259	0	20	57	92	18	1	0	ok
1163	2026-08-01 04:19:17.215692+00	0.02	0	1906	1257	0	20	57	92	18	1	0	ok
1164	2026-08-01 04:19:36.51716+00	0.01	0	1906	1296	0	20	57	99	12	1	0	ok
1165	2026-08-01 04:20:36.516243+00	0	0	1906	1275	0	20	57	84	10	1	0	ok
1166	2026-08-01 04:21:36.518073+00	0.08	0	1906	1272	0	20	57	88	10	1	0	ok
1167	2026-08-01 04:22:36.520289+00	0.06	0	1906	1267	0	20	57	90	10	1	0	ok
1168	2026-08-01 04:23:36.520365+00	0.02	0	1906	1251	0	20	57	104	12	1	0	ok
1169	2026-08-01 04:24:36.517662+00	0.04	0	1906	1252	0	20	57	103	12	1	0	ok
1170	2026-08-01 04:25:36.519385+00	0.04	0	1906	1247	0	20	57	104	10	1	0	ok
1171	2026-08-01 04:26:36.520607+00	0.01	0	1906	1240	0	20	57	104	10	1	0	ok
1172	2026-08-01 04:27:36.519377+00	0.58	0	1906	1243	0	20	57	105	10	1	0	ok
1173	2026-08-01 04:28:36.521318+00	0.61	0	1906	1245	0	20	57	106	10	1	0	ok
1174	2026-08-01 04:29:36.521012+00	0.45	0	1906	1256	0	20	57	107	10	1	0	ok
1175	2026-08-01 04:30:36.524814+00	0.43	0	1906	1243	0	20	57	107	10	1	0	ok
1176	2026-08-01 04:31:36.521771+00	0.16	0.51	1906	1254	0	20	57	109	12	1	0	ok
1177	2026-08-01 04:32:36.523598+00	0.19	0	1906	1241	0	20	57	105	10	1	0	ok
1178	2026-08-01 04:33:36.521618+00	0.07	0	1906	1257	0	20	57	106	11	1	0	ok
1179	2026-08-01 04:34:36.524596+00	0.02	0	1906	1256	0	20	57	107	11	1	0	ok
1180	2026-08-01 04:35:36.523242+00	0.01	0	1906	1250	0	20	57	108	12	1	0	ok
1181	2026-08-01 04:36:36.522748+00	0	0	1906	1260	0	20	57	108	11	1	0	ok
1182	2026-08-01 04:37:36.524722+00	0	0	1906	1247	0	20	57	109	12	1	0	ok
1183	2026-08-01 04:38:36.524858+00	0	0	1906	1253	0	20	57	110	9	1	0	ok
1184	2026-08-01 04:39:36.525694+00	0	0	1906	1242	0	20	57	112	12	1	0	ok
1185	2026-08-01 04:40:36.526448+00	0	0	1906	1239	0	20	57	111	10	1	0	ok
1186	2026-08-01 04:41:36.527533+00	0	0	1906	1247	0	20	57	112	13	1	0	ok
1187	2026-08-01 04:42:36.528394+00	0	0	1906	1236	0	20	57	112	13	1	0	ok
1188	2026-08-01 04:43:36.528176+00	0	0	1906	1244	0	20	57	111	14	1	0	ok
1189	2026-08-01 04:44:36.52794+00	0	0	1906	1246	0	20	57	111	12	1	0	ok
1190	2026-08-01 04:45:36.527546+00	0.05	0	1906	1247	0	20	57	111	13	1	0	ok
1191	2026-08-01 04:46:36.535827+00	0.02	0	1906	1240	0	20	57	111	9	1	0	ok
1192	2026-08-01 04:47:36.527927+00	0	0	1906	1250	0	20	57	112	10	1	0	ok
1193	2026-08-01 04:48:36.528321+00	0	0	1906	1253	0	20	57	111	9	1	0	ok
1194	2026-08-01 04:49:36.529136+00	0	0	1906	1251	0	20	57	111	9	1	0	ok
1195	2026-08-01 04:50:36.528172+00	0	0	1906	1254	0	20	57	112	9	1	0	ok
1196	2026-08-01 04:51:36.529238+00	0	0	1906	1241	0	20	57	113	10	1	0	ok
1197	2026-08-01 04:52:36.529601+00	0	0	1906	1244	0	20	57	113	10	1	0	ok
1198	2026-08-01 04:53:36.534241+00	0	0	1906	1236	0	20	57	112	10	1	0	ok
1199	2026-08-01 04:54:36.531615+00	0	0	1906	1243	0	20	57	113	10	1	0	ok
1200	2026-08-01 04:55:36.53179+00	0	0	1906	1235	0	20	57	113	10	1	0	ok
1201	2026-08-01 04:56:36.532318+00	0	0	1906	1240	0	20	57	113	10	1	0	ok
1202	2026-08-01 04:57:36.533505+00	0	0	1906	1245	0	20	57	113	10	1	0	ok
1203	2026-08-01 04:58:36.533142+00	0	0	1906	1245	0	20	57	113	10	1	0	ok
1204	2026-08-01 04:59:36.533745+00	0	0	1906	1234	0	20	57	114	10	1	0	ok
1205	2026-08-01 05:00:36.532843+00	0	0	1906	1244	0	20	57	113	10	1	0	ok
1206	2026-08-01 05:01:36.532877+00	0	0.5	1906	1238	0	20	57	113	10	1	0	ok
1207	2026-08-01 05:02:36.532477+00	0	0	1906	1239	0	20	57	113	10	1	0	ok
1208	2026-08-01 05:03:36.532553+00	0	0	1906	1255	0	20	57	113	10	1	0	ok
1209	2026-08-01 05:04:36.534483+00	0	0	1906	1247	0	20	57	113	10	1	0	ok
1210	2026-08-01 05:05:36.534971+00	0.07	0	1906	1252	0	20	57	113	10	1	0	ok
1211	2026-08-01 05:06:36.535533+00	0.02	0	1906	1250	0	20	57	113	10	1	0	ok
1212	2026-08-01 05:07:36.534537+00	0.27	0	1906	1241	0	20	57	114	10	1	0	ok
1213	2026-08-01 05:08:36.536069+00	0.1	0	1906	1240	0	20	57	113	10	1	0	ok
1214	2026-08-01 05:09:36.536117+00	0.03	0	1906	1237	0	20	57	113	10	1	0	ok
1215	2026-08-01 05:10:36.53718+00	0.01	0	1906	1248	0	20	57	114	10	1	0	ok
1216	2026-08-01 05:11:36.538274+00	0	0	1906	1236	0	20	57	114	10	1	0	ok
1217	2026-08-01 05:12:36.538484+00	0.27	0	1906	1235	0	20	57	114	10	1	0	ok
1218	2026-08-01 05:13:36.540356+00	0.1	0	1906	1239	0	20	57	114	11	1	0	ok
1219	2026-08-01 05:14:36.540171+00	0.03	0	1906	1228	0	20	57	114	10	1	0	ok
1220	2026-08-01 05:15:36.542866+00	0.28	0	1906	1243	0	20	57	114	11	1	0	ok
1221	2026-08-01 05:16:36.542781+00	0.1	0	1906	1239	0	20	57	113	10	1	0	ok
1222	2026-08-01 05:17:36.54398+00	0.04	0.5	1906	1241	0	20	57	114	10	1	0	ok
1223	2026-08-01 05:18:36.544094+00	0.01	0	1906	1245	0	20	57	114	10	1	0	ok
1224	2026-08-01 05:19:36.546857+00	0.31	0	1906	1239	0	20	57	114	12	1	0	ok
1225	2026-08-01 05:20:36.546076+00	0.38	0	1906	1245	0	20	57	114	10	1	0	ok
1226	2026-08-01 05:21:36.54853+00	0.14	0	1906	1253	0	20	57	114	10	1	0	ok
1227	2026-08-01 05:22:36.54851+00	0.05	0	1906	1252	0	20	57	115	10	1	0	ok
1228	2026-08-01 05:23:36.55028+00	0.02	0	1906	1239	0	20	57	114	13	1	0	ok
1229	2026-08-01 05:24:36.549996+00	0	0	1906	1251	0	20	57	114	11	1	0	ok
1230	2026-08-01 05:25:36.552462+00	0.45	0	1906	1249	0	20	57	114	11	1	0	ok
1231	2026-08-01 05:26:36.553178+00	0.16	0	1906	1235	0	20	57	115	11	1	0	ok
1232	2026-08-01 05:27:36.553458+00	0.37	0	1906	1243	0	20	57	114	11	1	0	ok
1233	2026-08-01 05:28:36.555542+00	0.13	0	1906	1237	0	20	57	115	11	1	0	ok
1234	2026-08-01 05:29:36.555368+00	0.05	0	1906	1237	0	20	57	114	14	1	0	ok
1235	2026-08-01 05:30:36.556147+00	0.02	0	1906	1252	0	20	57	114	11	1	0	ok
1236	2026-08-01 05:31:36.557418+00	0.04	0	1906	1240	0	20	57	114	12	1	0	ok
1237	2026-08-01 05:32:36.559655+00	0.01	0	1906	1240	0	20	57	115	11	1	0	ok
1238	2026-08-01 05:33:36.558987+00	0	0	1906	1248	0	20	57	115	13	1	0	ok
1239	2026-08-01 05:34:36.55994+00	0	0	1906	1247	0	20	57	114	11	1	0	ok
1240	2026-08-01 05:35:36.560624+00	0.32	0	1906	1250	0	20	57	114	12	1	0	ok
1241	2026-08-01 05:36:36.560756+00	0.21	0	1906	1250	0	20	57	115	11	1	0	ok
1242	2026-08-01 05:37:36.560862+00	0.51	0.5	1906	1245	0	20	57	115	12	1	0	ok
1243	2026-08-01 05:38:36.559738+00	0.19	0	1906	1249	0	20	57	114	11	1	0	ok
1244	2026-08-01 05:39:36.560709+00	0.07	0	1906	1248	0	20	57	114	12	1	0	ok
1245	2026-08-01 05:40:36.561796+00	0.22	0	1906	1243	0	20	57	114	11	1	0	ok
1246	2026-08-01 05:41:36.5606+00	0.08	0	1906	1247	0	20	57	115	11	1	0	ok
1247	2026-08-01 05:42:36.560422+00	0.08	0	1906	1253	0	20	57	114	10	1	0	ok
1248	2026-08-01 05:43:36.560103+00	0.27	0	1906	1239	0	20	57	114	10	1	0	ok
1249	2026-08-01 05:44:36.560289+00	0.1	0	1906	1235	0	20	57	114	10	1	0	ok
1250	2026-08-01 05:45:36.559754+00	0.03	0	1906	1248	0	20	57	115	10	1	0	ok
1251	2026-08-01 05:46:36.561613+00	0.06	0	1906	1248	0	20	57	112	10	1	0	ok
1252	2026-08-01 05:47:36.560449+00	0.07	0	1906	1240	0	20	57	113	10	1	0	ok
1253	2026-08-01 05:48:36.559381+00	0.06	0	1906	1255	0	20	57	112	10	1	0	ok
1254	2026-08-01 05:49:36.559019+00	0.07	0	1906	1253	0	20	57	112	10	1	0	ok
1255	2026-08-01 05:50:36.561284+00	0.27	0	1906	1237	0	20	57	113	10	1	0	ok
1256	2026-08-01 05:51:36.561024+00	0.1	0	1906	1250	0	20	57	114	10	1	0	ok
1257	2026-08-01 05:52:36.563701+00	0.03	0	1906	1250	0	20	57	113	10	1	0	ok
1258	2026-08-01 05:53:36.561517+00	0.06	0	1906	1245	0	20	57	114	10	1	0	ok
1259	2026-08-01 05:54:36.561884+00	0.21	0	1906	1242	0	20	57	114	10	1	0	ok
1260	2026-08-01 05:55:36.562266+00	0.22	0	1906	1247	0	20	57	114	10	1	0	ok
1261	2026-08-01 05:56:36.561677+00	0.11	0	1906	1244	0	20	57	113	10	1	0	ok
1262	2026-08-01 05:57:36.560982+00	0.09	0	1906	1247	0	20	57	114	10	1	0	ok
1263	2026-08-01 05:58:36.563015+00	0.22	0	1906	1242	0	20	57	114	10	1	0	ok
1264	2026-08-01 05:59:36.56333+00	0.32	0	1906	1234	0	20	57	114	10	1	0	ok
1265	2026-08-01 06:00:36.562869+00	0.12	0	1906	1249	0	20	57	114	10	1	0	ok
1266	2026-08-01 06:01:36.562754+00	0.09	0	1906	1248	0	20	57	114	10	1	0	ok
1267	2026-08-01 06:02:36.562976+00	0.34	0	1906	1253	0	20	57	114	10	1	0	ok
1268	2026-08-01 06:03:36.566267+00	0.37	0	1906	1240	0	20	57	114	11	1	0	ok
1269	2026-08-01 06:04:36.564155+00	0.41	0	1906	1238	0	20	57	114	10	1	0	ok
1270	2026-08-01 06:05:36.56638+00	0.73	0	1906	1238	0	20	57	114	11	1	0	ok
1271	2026-08-01 06:06:36.565809+00	0.32	0	1906	1238	0	20	57	114	13	1	0	ok
1272	2026-08-01 06:07:36.564969+00	0.66	0	1906	1246	0	20	57	115	12	1	0	ok
1273	2026-08-01 06:08:36.56696+00	0.29	0	1906	1237	0	20	57	114	18	1	0	ok
1274	2026-08-01 06:09:36.566472+00	0.35	0	1906	1243	0	20	57	114	11	1	0	ok
1275	2026-08-01 06:10:36.568304+00	0.27	0	1906	1235	0	20	57	114	10	1	0	ok
1276	2026-08-01 06:11:36.568293+00	0.1	0	1906	1243	0	20	57	114	11	1	0	ok
1277	2026-08-01 06:12:36.568157+00	0.08	0	1906	1237	0	20	57	109	10	1	0	ok
1278	2026-08-01 06:13:36.568354+00	0.13	0	1906	1247	0	20	57	114	10	1	0	ok
1279	2026-08-01 06:14:36.572242+00	0.29	0	1906	1231	0	20	57	117	10	1	0	ok
1280	2026-08-01 06:15:36.568234+00	0.15	0	1906	1235	0	20	57	116	10	1	0	ok
1281	2026-08-01 06:16:36.56879+00	0.1	0	1906	1227	0	20	57	117	12	1	0	ok
1282	2026-08-01 06:17:36.569834+00	0.08	0	1906	1238	0	20	57	117	13	1	0	ok
1283	2026-08-01 06:18:36.570615+00	0.17	0	1906	1240	0	20	57	119	8	1	0	ok
1284	2026-08-01 06:19:36.569498+00	0.37	0	1906	1237	0	20	57	120	10	1	0	ok
1285	2026-08-01 06:20:36.571147+00	0.13	0	1906	1238	0	20	57	119	11	1	0	ok
1286	2026-08-01 06:21:36.57236+00	0.1	0	1906	1236	0	20	57	120	12	1	0	ok
1287	2026-08-01 06:22:36.573325+00	0.08	0	1906	1233	0	20	57	120	10	1	0	ok
1288	2026-08-01 06:23:36.573116+00	0.16	0	1906	1247	0	20	57	119	10	1	0	ok
1289	2026-08-01 06:24:36.572615+00	0.15	0	1906	1238	0	20	57	120	11	1	0	ok
1290	2026-08-01 06:25:36.571456+00	0.3	0	1906	1231	0	20	57	120	10	1	0	ok
1291	2026-08-01 06:26:36.572759+00	0.2	0	1906	1235	0	20	57	120	12	1	0	ok
1292	2026-08-01 06:27:36.573883+00	0.27	0	1906	1234	0	20	57	120	10	1	0	ok
1293	2026-08-01 06:28:36.573651+00	0.42	0.5	1906	1238	0	20	57	120	10	1	0	ok
1294	2026-08-01 06:29:36.576597+00	0.4	0	1906	1237	0	20	57	120	11	1	0	ok
1295	2026-08-01 06:30:36.575906+00	0.68	0	1906	1239	0	20	57	120	12	1	0	ok
1296	2026-08-01 06:31:36.577282+00	0.3	0	1906	1236	0	20	57	121	13	1	0	ok
1297	2026-08-01 06:32:36.577428+00	0.2	0	1906	1235	0	20	57	120	10	1	0	ok
1298	2026-08-01 06:33:36.579477+00	0.48	0	1906	1244	0	20	57	120	12	1	0	ok
1299	2026-08-01 06:34:36.580845+00	0.42	0	1906	1231	0	20	57	120	11	1	0	ok
1300	2026-08-01 06:35:36.579678+00	0.2	0	1906	1227	0	20	57	120	11	1	0	ok
1301	2026-08-01 06:36:36.581043+00	0.46	0	1906	1230	0	20	57	120	12	1	0	ok
1302	2026-08-01 06:37:36.581154+00	0.22	0	1906	1240	0	20	57	120	9	1	0	ok
1303	2026-08-01 06:38:36.582418+00	0.13	0	1906	1231	0	20	57	120	15	1	0	ok
1304	2026-08-01 06:39:36.585987+00	0.24	0	1906	1234	0	20	57	120	13	1	0	ok
1305	2026-08-01 06:40:36.585336+00	0.33	0	1906	1229	0	20	57	120	12	1	0	ok
1306	2026-08-01 06:41:36.585179+00	0.17	0.5	1906	1228	0	20	57	120	10	1	0	ok
1307	2026-08-01 06:42:36.586233+00	0.25	0	1906	1232	0	20	57	121	10	1	0	ok
1308	2026-08-01 06:43:36.588286+00	0.14	0	1906	1235	0	20	57	120	10	1	0	ok
1309	2026-08-01 06:44:36.587273+00	0.14	0	1906	1234	0	20	57	121	10	1	0	ok
1310	2026-08-01 06:45:36.58735+00	0.25	0	1906	1234	0	20	57	121	10	1	0	ok
1311	2026-08-01 06:46:36.591677+00	0.14	0	1906	1229	0	20	57	121	11	1	0	ok
1312	2026-08-01 06:47:36.590054+00	0.1	0	1906	1235	0	20	57	121	10	1	0	ok
1313	2026-08-01 06:48:36.592035+00	0.6	0	1906	1231	0	20	57	123	10	1	0	ok
1314	2026-08-01 06:49:36.591614+00	0.22	0	1906	1225	0	20	57	122	10	1	0	ok
1315	2026-08-01 06:50:36.592969+00	0.27	0	1906	1237	0	20	57	122	10	1	0	ok
1316	2026-08-01 06:51:36.593976+00	0.24	0.5	1906	1243	0	20	57	115	11	1	0	ok
1317	2026-08-01 06:52:36.597499+00	0.14	0	1906	1247	0	20	57	116	11	1	0	ok
1318	2026-08-01 06:53:36.598511+00	0.1	0	1906	1230	0	20	57	120	19	1	0	ok
1319	2026-08-01 06:54:36.596603+00	0.33	0	1906	1245	0	20	57	120	10	1	0	ok
1320	2026-08-01 06:55:36.609387+00	0.49	0	1906	1231	2	20	56	120	14	1	0	ok
1321	2026-08-01 06:56:36.596225+00	0.3	0	1906	1231	2	20	56	120	12	1	0	ok
1322	2026-08-01 06:57:36.596548+00	0.16	0	1906	1227	2	20	56	121	9	1	0	ok
1323	2026-08-01 06:58:36.598125+00	0.1	0	1906	1229	2	20	56	121	9	1	0	ok
1324	2026-08-01 06:59:36.597168+00	0.08	0	1906	1227	2	20	56	121	11	1	0	ok
1325	2026-08-01 07:00:36.598644+00	0.17	0.5	1906	1235	2	20	56	122	10	1	0	ok
1326	2026-08-01 07:01:36.598039+00	0.21	0	1906	1231	2	20	56	122	12	1	0	ok
1327	2026-08-01 07:02:36.597097+00	0.12	0	1906	1241	0	20	56	121	11	1	0	ok
1328	2026-08-01 07:03:36.598866+00	0.09	0	1906	1250	0	20	56	123	10	1	0	ok
1329	2026-08-01 07:04:36.597624+00	0.08	0	1906	1249	0	20	56	122	9	1	0	ok
1330	2026-08-01 07:05:36.597825+00	0.08	0	1906	1257	0	20	56	122	10	1	0	ok
1331	2026-08-01 07:06:36.598956+00	0.27	0	1906	1244	0	20	56	123	12	1	0	ok
1332	2026-08-01 07:07:36.598071+00	0.1	0	1906	1246	0	20	56	122	10	1	0	ok
1333	2026-08-01 07:08:36.59866+00	0.08	0	1906	1246	0	20	56	123	10	1	0	ok
1334	2026-08-01 07:09:36.597388+00	0.08	0	1906	1260	0	20	56	123	10	1	0	ok
1335	2026-08-01 07:10:36.599243+00	0.08	0	1906	1257	0	20	56	123	10	1	0	ok
1336	2026-08-01 07:11:36.597881+00	0.11	0	1906	1242	0	20	56	123	11	1	0	ok
1337	2026-08-01 07:12:36.601412+00	0.09	0	1906	1242	0	20	56	123	11	1	0	ok
1338	2026-08-01 07:13:36.5985+00	0.08	0	1906	1252	0	20	56	125	10	1	0	ok
1339	2026-08-01 07:14:36.599964+00	0.08	0	1906	1241	0	20	56	126	10	1	0	ok
1340	2026-08-01 07:15:36.599342+00	0.37	0	1906	1251	0	20	56	124	10	1	0	ok
1341	2026-08-01 07:16:36.60064+00	0.23	0	1906	1246	0	20	56	123	11	1	0	ok
1342	2026-08-01 07:17:36.601177+00	0.13	0	1906	1244	0	20	57	124	10	1	0	ok
1343	2026-08-01 07:18:36.607242+00	0.1	0	1906	1246	0	20	57	124	10	1	0	ok
1344	2026-08-01 07:19:36.604089+00	0.08	0	1906	1241	0	20	57	125	10	1	0	ok
1345	2026-08-01 07:20:36.603916+00	0.22	0	1906	1250	0	20	57	123	10	1	0	ok
1346	2026-08-01 07:21:36.604083+00	0.13	0	1906	1249	0	20	57	126	10	1	0	ok
1347	2026-08-01 07:22:25.677041+00	0.24	0	1906	1293	0	20	57	99	12	1	0	ok
1348	2026-08-01 07:23:25.709243+00	0.2	0	1906	1263	0	20	57	96	15	1	0	ok
1349	2026-08-01 07:24:25.682478+00	0.13	0.5	1906	1252	0	20	57	102	16	1	0	ok
1350	2026-08-01 07:25:25.682457+00	0.1	0	1906	1261	0	20	57	100	14	1	0	ok
1351	2026-08-01 07:26:25.682612+00	0.09	0	1906	1252	0	20	57	104	15	1	0	ok
1352	2026-08-01 07:27:25.681902+00	0.09	0	1906	1258	0	20	57	106	14	1	0	ok
1353	2026-08-01 07:28:25.682507+00	0.15	0	1906	1248	0	20	57	106	14	1	0	ok
1354	2026-08-01 07:29:25.682219+00	0.11	0	1906	1249	0	20	57	107	15	1	0	ok
1355	2026-08-01 07:30:25.683269+00	0.31	0	1906	1246	0	20	57	108	17	1	0	ok
1356	2026-08-01 07:31:25.682984+00	0.23	0	1906	1239	0	20	57	108	17	1	0	ok
1357	2026-08-01 07:32:25.683267+00	0.14	0	1906	1245	0	20	57	108	17	1	0	ok
1358	2026-08-01 07:33:25.683468+00	0.31	0	1906	1239	0	20	57	108	18	1	0	ok
1359	2026-08-01 07:34:25.683732+00	0.17	0	1906	1231	0	20	57	109	18	1	0	ok
1360	2026-08-01 07:35:25.684734+00	0.12	0.5	1906	1245	0	20	57	108	18	1	0	ok
1361	2026-08-01 07:36:25.683922+00	0.1	0	1906	1236	0	20	57	109	19	1	0	ok
1362	2026-08-01 07:37:25.683923+00	0.09	0	1906	1238	0	20	57	108	18	1	0	ok
1363	2026-08-01 07:38:25.682459+00	0.09	0.5	1906	1243	0	20	57	109	17	1	0	ok
1364	2026-08-01 07:39:25.682784+00	0.09	0	1906	1233	0	20	57	109	15	1	0	ok
1365	2026-08-01 07:40:25.685913+00	0.2	0	1906	1248	0	20	57	102	17	1	0	ok
1366	2026-08-01 07:41:25.684587+00	0.13	0	1906	1239	0	20	57	108	17	1	0	ok
1367	2026-08-01 07:42:25.685477+00	0.1	0	1906	1237	0	20	57	110	17	1	0	ok
1368	2026-08-01 07:43:25.684858+00	0.09	0	1906	1233	0	20	57	110	16	1	0	ok
1369	2026-08-01 07:44:25.687653+00	0.15	0	1906	1233	0	20	57	111	18	1	0	ok
1370	2026-08-01 07:45:25.684699+00	0.17	0.5	1906	1231	0	20	57	112	17	1	0	ok
1371	2026-08-01 07:46:25.68698+00	0.17	0	1906	1232	0	20	57	112	18	1	0	ok
1372	2026-08-01 07:47:25.686728+00	0.12	0	1906	1239	0	20	57	112	15	1	0	ok
1373	2026-08-01 07:48:25.685566+00	0.1	0	1906	1242	0	20	57	112	16	1	0	ok
1374	2026-08-01 07:49:25.689854+00	0.15	0	1906	1236	0	20	57	112	16	1	0	ok
1375	2026-08-01 07:50:25.69499+00	0.05	0	1906	1231	0	20	57	112	16	1	0	ok
1376	2026-08-01 07:51:25.685033+00	0.08	0	1906	1238	0	20	57	112	16	1	0	ok
1377	2026-08-01 07:52:25.687028+00	0.08	0	1906	1234	0	20	57	114	15	1	0	ok
1378	2026-08-01 07:53:25.686631+00	0.03	0	1906	1231	0	20	57	112	16	1	0	ok
1379	2026-08-01 07:54:25.687111+00	0.12	0	1906	1233	0	20	57	113	16	1	0	ok
1380	2026-08-01 07:55:25.688274+00	0.1	0	1906	1232	0	20	57	112	14	1	0	ok
1381	2026-08-01 07:56:25.687517+00	0.09	0	1906	1236	0	20	57	112	14	1	0	ok
1382	2026-08-01 07:57:25.686769+00	0.09	0	1906	1237	0	20	57	112	16	1	0	ok
1383	2026-08-01 07:58:25.689216+00	0.09	0	1906	1237	0	20	57	112	13	1	0	ok
1384	2026-08-01 07:59:25.68833+00	0.09	0	1906	1243	0	20	57	112	13	1	0	ok
1385	2026-08-01 08:00:25.689249+00	0.15	0	1906	1231	0	20	57	119	17	1	0	ok
1386	2026-08-01 08:01:25.689593+00	0.28	0	1906	1225	0	20	57	118	17	1	0	ok
1387	2026-08-01 08:02:25.690305+00	0.16	0	1906	1228	0	20	57	119	15	1	0	ok
1388	2026-08-01 08:03:25.690282+00	0.11	0	1906	1223	0	20	57	119	14	1	0	ok
1389	2026-08-01 08:04:25.689599+00	0.33	0	1906	1225	0	20	57	118	14	1	0	ok
1390	2026-08-01 08:05:25.69+00	0.17	0	1906	1222	0	20	57	118	18	1	0	ok
1391	2026-08-01 08:06:25.691517+00	0.12	0	1906	1226	0	20	57	118	18	1	0	ok
1392	2026-08-01 08:07:25.69116+00	0.32	0	1906	1231	0	20	57	118	17	1	0	ok
1393	2026-08-01 08:08:25.691749+00	0.17	0	1906	1230	0	20	57	118	18	1	0	ok
1394	2026-08-01 08:09:25.692286+00	0.23	0	1906	1231	0	20	57	118	17	1	0	ok
1395	2026-08-01 08:10:25.692135+00	0.14	0	1906	1233	0	20	57	118	18	1	0	ok
1396	2026-08-01 08:11:25.691811+00	0.11	0	1906	1239	0	20	57	119	14	1	0	ok
1397	2026-08-01 08:12:25.691354+00	0.1	0	1906	1227	0	20	57	119	17	1	0	ok
1398	2026-08-01 08:13:25.695715+00	0.09	0	1906	1234	0	20	57	119	15	1	0	ok
1399	2026-08-01 08:14:25.697461+00	0.09	0	1906	1227	0	20	57	119	16	1	0	ok
1400	2026-08-01 08:15:25.696703+00	0.38	0	1906	1229	0	20	57	119	14	1	0	ok
1401	2026-08-01 08:16:25.696785+00	0.23	0	1906	1231	0	20	57	119	16	1	0	ok
1402	2026-08-01 08:17:25.697316+00	0.14	0	1906	1241	0	20	57	119	12	1	0	ok
1403	2026-08-01 08:18:25.698743+00	0.18	0	1906	1238	0	20	57	119	15	1	0	ok
1404	2026-08-01 08:19:25.695942+00	0.12	0	1906	1219	0	20	57	119	13	1	0	ok
1405	2026-08-01 08:20:25.695679+00	0.21	0	1906	1223	0	20	57	119	14	1	0	ok
1406	2026-08-01 08:21:25.696502+00	0.48	0	1906	1214	0	20	57	119	13	1	0	ok
1407	2026-08-01 08:22:25.695441+00	0.17	0	1906	1237	0	20	57	119	11	1	0	ok
1408	2026-08-01 08:23:25.69611+00	0.12	0	1906	1223	0	20	57	118	15	1	0	ok
1409	2026-08-01 08:24:25.696153+00	0.1	0	1906	1238	0	20	57	118	12	1	0	ok
1410	2026-08-01 08:25:25.697349+00	0.09	0	1906	1232	0	20	57	118	15	1	0	ok
1411	2026-08-01 08:26:25.69744+00	0.18	0	1906	1233	0	20	57	118	13	1	0	ok
1412	2026-08-01 08:27:25.695813+00	0.07	0	1906	1231	0	20	57	118	13	1	0	ok
1413	2026-08-01 08:28:25.696593+00	0.02	0	1906	1228	0	20	57	117	16	1	0	ok
1414	2026-08-01 08:29:25.698528+00	0.01	0	1906	1237	0	20	57	118	11	1	0	ok
1415	2026-08-01 08:30:25.69871+00	0.12	0	1906	1239	0	20	57	118	12	1	0	ok
1416	2026-08-01 08:31:25.699546+00	0.1	0	1906	1231	0	20	57	117	15	1	0	ok
1417	2026-08-01 08:32:25.699461+00	0.09	0	1906	1233	0	20	57	118	16	1	0	ok
1418	2026-08-01 08:33:25.700367+00	0.09	0	1906	1231	0	20	57	118	17	1	0	ok
1419	2026-08-01 08:34:25.699567+00	0.26	0	1906	1229	0	20	57	118	16	1	0	ok
1420	2026-08-01 08:35:25.700836+00	0.09	0	1906	1239	0	20	57	117	14	1	0	ok
1421	2026-08-01 08:36:25.700684+00	0.09	0	1906	1229	0	20	57	117	15	1	0	ok
1422	2026-08-01 08:37:25.698563+00	0.09	0	1906	1237	0	20	57	118	14	1	0	ok
1423	2026-08-01 08:38:25.699328+00	0.09	0	1906	1233	0	20	57	118	14	1	0	ok
1424	2026-08-01 08:39:25.699693+00	0.09	0	1906	1228	0	20	57	118	13	1	0	ok
1425	2026-08-01 08:40:25.700762+00	0.09	0	1906	1232	0	20	57	117	13	1	0	ok
1426	2026-08-01 08:41:25.699646+00	0.09	0	1906	1236	0	20	57	119	13	1	0	ok
1427	2026-08-01 08:42:25.701043+00	0.14	0	1906	1229	0	20	57	118	13	1	0	ok
1428	2026-08-01 08:43:25.701352+00	0.28	0	1906	1237	0	20	57	121	14	1	0	ok
1429	2026-08-01 08:44:25.700647+00	0.1	0	1906	1228	0	20	57	121	18	1	0	ok
1430	2026-08-01 08:45:25.70295+00	0.09	0	1906	1229	0	20	57	120	17	1	0	ok
1431	2026-08-01 08:46:25.704227+00	0.09	0	1906	1233	0	20	57	120	16	1	0	ok
1432	2026-08-01 08:47:25.702627+00	0.03	0	1906	1221	0	20	57	121	14	1	0	ok
1433	2026-08-01 08:48:25.7019+00	0.07	0	1906	1239	0	20	57	121	13	1	0	ok
1434	2026-08-01 08:49:25.703058+00	0.02	0	1906	1225	0	20	57	121	17	1	0	ok
1435	2026-08-01 08:50:25.70724+00	0.1	0	1906	1223	0	20	57	121	17	1	0	ok
1436	2026-08-01 08:51:25.706534+00	0.04	0	1906	1230	0	20	57	121	17	1	0	ok
1437	2026-08-01 08:52:25.70634+00	0.01	0	1906	1225	0	20	57	121	15	1	0	ok
1438	2026-08-01 08:53:25.707594+00	0	0	1906	1229	0	20	57	121	14	1	0	ok
1439	2026-08-01 08:54:25.706379+00	0.06	0	1906	1231	0	20	57	121	15	1	0	ok
1440	2026-08-01 08:55:25.707316+00	0.08	0	1906	1235	0	20	57	121	13	1	0	ok
1441	2026-08-01 08:56:25.707038+00	0.03	0	1906	1236	0	20	57	121	12	1	0	ok
1442	2026-08-01 08:57:25.70754+00	0.07	0	1906	1237	0	20	57	120	12	1	0	ok
1443	2026-08-01 08:58:25.706432+00	0.11	0	1906	1233	0	20	57	121	12	1	0	ok
1444	2026-08-01 08:59:25.707616+00	0.04	0	1906	1231	0	20	57	120	12	1	0	ok
1445	2026-08-01 09:00:25.708576+00	0.07	0	1906	1237	0	20	57	120	12	1	0	ok
1446	2026-08-01 09:01:25.709759+00	0.08	0	1906	1234	0	20	57	121	12	1	0	ok
1447	2026-08-01 09:02:25.709611+00	0.03	0	1906	1235	0	20	57	121	12	1	0	ok
1448	2026-08-01 09:03:25.714443+00	0.06	0	1906	1239	0	20	57	121	12	1	0	ok
1449	2026-08-01 09:04:25.714401+00	0.08	0	1906	1233	0	20	57	121	15	1	0	ok
1450	2026-08-01 09:05:25.71319+00	0.03	0	1906	1229	0	20	57	121	14	1	0	ok
1451	2026-08-01 09:06:25.713691+00	0.07	0	1906	1224	0	20	57	121	15	1	0	ok
1452	2026-08-01 09:07:25.713452+00	0.02	0	1906	1233	0	20	57	121	14	1	0	ok
1453	2026-08-01 09:08:25.713546+00	0.01	0	1906	1224	0	20	57	121	15	1	0	ok
1454	2026-08-01 09:09:25.712837+00	0	0	1906	1233	0	20	57	121	14	1	0	ok
1455	2026-08-01 09:10:25.714272+00	0.11	0	1906	1223	0	20	57	121	18	1	0	ok
1456	2026-08-01 09:11:25.715663+00	0.04	0	1906	1223	0	20	57	121	17	1	0	ok
1457	2026-08-01 09:12:25.71576+00	0.07	0	1906	1215	0	20	57	122	18	1	0	ok
1458	2026-08-01 09:13:25.716966+00	0.02	0	1906	1225	0	20	57	121	17	1	0	ok
1459	2026-08-01 09:14:25.716514+00	0.01	0	1906	1228	0	20	57	121	18	1	0	ok
1460	2026-08-01 09:15:25.718409+00	0.11	0	1906	1226	0	20	57	121	17	1	0	ok
1461	2026-08-01 09:16:25.719102+00	0.04	0	1906	1224	0	20	57	121	18	1	0	ok
1462	2026-08-01 09:17:25.719812+00	0.01	0	1906	1228	0	20	57	112	17	1	0	ok
1463	2026-08-01 09:18:25.721447+00	0	0	1906	1229	0	20	57	115	18	1	0	ok
1464	2026-08-01 09:19:25.72106+00	0.05	0	1906	1229	0	20	57	116	17	1	0	ok
1465	2026-08-01 09:20:25.721452+00	0.02	0	1906	1235	0	20	57	118	18	1	0	ok
1466	2026-08-01 09:21:25.723072+00	0	0	1906	1231	0	20	57	119	17	1	0	ok
1467	2026-08-01 09:22:25.723743+00	0	0	1906	1230	0	20	57	121	18	1	0	ok
1468	2026-08-01 09:23:25.727104+00	0	0	1906	1224	0	20	57	119	17	1	0	ok
1469	2026-08-01 09:24:25.726106+00	0.06	0	1906	1232	0	20	57	119	18	1	0	ok
1470	2026-08-01 09:25:25.725707+00	0.02	0	1906	1230	0	20	57	119	15	1	0	ok
1471	2026-08-01 09:26:25.726375+00	0	0	1906	1244	0	20	57	119	14	1	0	ok
1472	2026-08-01 09:27:25.729186+00	0	0	1906	1232	0	20	57	119	14	1	0	ok
1473	2026-08-01 09:28:25.731661+00	0	0	1906	1228	0	20	57	120	16	1	0	ok
1474	2026-08-01 09:29:25.730684+00	0	0	1906	1229	0	20	57	119	15	1	0	ok
1475	2026-08-01 09:30:25.731316+00	0.06	0	1906	1228	0	20	57	120	13	1	0	ok
1476	2026-08-01 09:31:25.733435+00	0.02	0	1906	1234	0	20	57	120	14	1	0	ok
1477	2026-08-01 09:32:25.732883+00	0	0	1906	1229	0	20	57	119	12	1	0	ok
1478	2026-08-01 09:33:25.733324+00	0	0	1906	1239	0	20	57	120	13	1	0	ok
1479	2026-08-01 09:34:25.734509+00	0	0	1906	1238	0	20	57	120	15	1	0	ok
1480	2026-08-01 09:35:25.73564+00	0	0	1906	1245	0	20	57	120	12	1	0	ok
1481	2026-08-01 09:36:25.736272+00	0	0	1906	1234	0	20	57	120	14	1	0	ok
1482	2026-08-01 09:37:25.73628+00	0	0	1906	1241	0	20	57	119	13	1	0	ok
1483	2026-08-01 09:38:25.737176+00	0.06	0	1906	1235	0	20	57	120	13	1	0	ok
1484	2026-08-01 09:39:25.737621+00	0.02	0.5	1906	1239	0	20	57	120	15	1	0	ok
1485	2026-08-01 09:40:25.740964+00	0.01	0	1906	1240	0	20	57	120	17	1	0	ok
1486	2026-08-01 09:41:25.741519+00	0	0	1906	1235	0	20	57	119	17	1	0	ok
1487	2026-08-01 09:42:25.740832+00	0	0	1906	1246	0	20	57	120	15	1	0	ok
1488	2026-08-01 09:43:25.740533+00	0	0	1906	1249	0	20	57	120	14	1	0	ok
1489	2026-08-01 09:44:25.739818+00	0	0	1906	1242	0	20	57	120	17	1	0	ok
1490	2026-08-01 09:45:25.740479+00	0	0	1906	1245	0	20	57	120	16	1	0	ok
1491	2026-08-01 09:46:25.741034+00	0	0	1906	1231	0	20	57	120	18	1	0	ok
1492	2026-08-01 09:47:25.740716+00	0	0	1906	1244	0	20	57	120	17	1	0	ok
1493	2026-08-01 09:48:25.741366+00	0	0	1906	1247	0	20	57	120	16	1	0	ok
1494	2026-08-01 09:49:25.740535+00	0	0	1906	1238	0	20	57	120	17	1	0	ok
1495	2026-08-01 09:50:25.74104+00	0	0	1906	1239	0	20	57	120	16	1	0	ok
1496	2026-08-01 09:51:25.741166+00	0	0	1906	1242	0	20	57	120	13	1	0	ok
1497	2026-08-01 09:52:25.741082+00	0	0	1906	1245	0	20	57	120	12	1	0	ok
1498	2026-08-01 09:53:25.742179+00	0	0	1906	1241	0	20	57	120	12	1	0	ok
1499	2026-08-01 09:54:25.742177+00	0	0	1906	1250	0	20	57	120	12	1	0	ok
1500	2026-08-01 09:55:25.742032+00	0	0	1906	1249	0	20	57	120	13	1	0	ok
1501	2026-08-01 09:56:25.743085+00	0	0	1906	1248	0	20	57	121	13	1	0	ok
1502	2026-08-01 09:57:25.742111+00	0	0	1906	1244	0	20	57	120	13	1	0	ok
1503	2026-08-01 09:58:25.742547+00	0	0	1906	1255	0	20	57	120	12	1	0	ok
1504	2026-08-01 09:59:25.743495+00	0.4	0	1906	1245	0	20	57	120	13	1	0	ok
1505	2026-08-01 10:00:25.74365+00	0.48	0	1906	1248	0	20	57	120	13	1	0	ok
1506	2026-08-01 10:01:25.744677+00	0.33	0	1906	1247	0	20	57	121	14	1	0	ok
1507	2026-08-01 10:02:25.74357+00	0.12	0.5	1906	1239	0	20	57	120	13	1	0	ok
1508	2026-08-01 10:03:25.748383+00	0.1	0	1906	1232	0	20	57	120	16	1	0	ok
1509	2026-08-01 10:04:25.746364+00	0.12	0	1906	1244	0	20	57	120	16	1	0	ok
1510	2026-08-01 10:05:25.746893+00	0.04	0	1906	1246	0	20	57	120	17	1	0	ok
1511	2026-08-01 10:06:25.746496+00	0.01	0	1906	1244	0	20	57	120	18	1	0	ok
1512	2026-08-01 10:07:25.746525+00	0	0	1906	1245	0	20	57	120	17	1	0	ok
1513	2026-08-01 10:08:25.747167+00	0	0	1906	1245	0	20	57	120	18	1	0	ok
1514	2026-08-01 10:09:25.747093+00	0	0	1906	1242	0	20	57	120	17	1	0	ok
1515	2026-08-01 10:10:25.754866+00	0.06	0	1906	1241	0	20	57	120	18	1	0	ok
1516	2026-08-01 10:11:25.747376+00	0.02	0	1906	1242	0	20	57	121	17	1	0	ok
1517	2026-08-01 10:12:25.747763+00	0.01	0	1906	1245	0	20	57	120	18	1	0	ok
1518	2026-08-01 10:13:25.748804+00	0	0	1906	1237	0	20	57	120	17	1	0	ok
1519	2026-08-01 10:14:25.746396+00	0	0	1906	1244	0	20	57	121	18	1	0	ok
1520	2026-08-01 10:15:25.748092+00	0	0	1906	1252	0	20	57	121	11	1	0	ok
1521	2026-08-01 10:16:25.747798+00	0	0.5	1906	1254	0	20	57	120	11	1	0	ok
1522	2026-08-01 10:17:25.748003+00	0	0	1906	1248	0	20	57	121	14	1	0	ok
1523	2026-08-01 10:18:25.749344+00	0	0	1906	1235	0	20	57	120	18	1	0	ok
1524	2026-08-01 10:19:25.749529+00	0	0	1906	1246	0	20	57	121	15	1	0	ok
1525	2026-08-01 10:20:25.748315+00	0	0	1906	1242	0	20	57	121	18	1	0	ok
1526	2026-08-01 10:21:25.748463+00	0	0	1906	1236	0	20	57	120	17	1	0	ok
1527	2026-08-01 10:22:25.74944+00	0	0	1906	1248	0	20	57	120	18	1	0	ok
1528	2026-08-01 10:23:25.749495+00	0	0	1906	1242	0	20	57	120	15	1	0	ok
1529	2026-08-01 10:24:25.749344+00	0	0	1906	1243	0	20	57	120	17	1	0	ok
1530	2026-08-01 10:25:25.751673+00	0	0	1906	1248	0	20	57	120	15	1	0	ok
1531	2026-08-01 10:26:25.750064+00	0	0	1906	1246	0	20	57	121	18	1	0	ok
1532	2026-08-01 10:27:25.753357+00	0.11	0	1906	1251	0	20	57	121	15	1	0	ok
1533	2026-08-01 10:28:25.755728+00	0.04	0	1906	1245	0	20	57	121	17	1	0	ok
1534	2026-08-01 10:29:25.756392+00	0.09	0	1906	1239	0	20	57	121	15	1	0	ok
1535	2026-08-01 10:30:25.756693+00	0.09	0	1906	1247	0	20	57	121	16	1	0	ok
1536	2026-08-01 10:31:25.755413+00	0.03	0	1906	1237	0	20	57	121	16	1	0	ok
1537	2026-08-01 10:32:25.756312+00	0.05	0	1906	1243	0	20	57	121	18	1	0	ok
1538	2026-08-01 10:33:25.757808+00	0.02	0	1906	1239	0	20	57	121	17	1	0	ok
1539	2026-08-01 10:34:25.756371+00	0	0	1906	1242	0	20	57	121	18	1	0	ok
1540	2026-08-01 10:35:25.757456+00	0	0	1906	1237	0	20	57	121	17	1	0	ok
1541	2026-08-01 10:36:25.760479+00	0	0.5	1906	1237	0	20	57	121	18	1	0	ok
1542	2026-08-01 10:37:25.759799+00	0	0	1906	1245	0	20	57	121	17	1	0	ok
1543	2026-08-01 10:38:25.759223+00	0	0	1906	1248	0	20	57	121	18	1	0	ok
1544	2026-08-01 10:39:25.759443+00	0	0	1906	1252	0	20	57	121	15	1	0	ok
1545	2026-08-01 10:40:25.760547+00	0	0	1906	1246	0	20	57	121	16	1	0	ok
1546	2026-08-01 10:41:25.76214+00	0	0	1906	1252	0	20	57	121	14	1	0	ok
1547	2026-08-01 10:42:25.762641+00	0	0	1906	1243	0	20	57	121	15	1	0	ok
1548	2026-08-01 10:43:25.760488+00	0	0	1906	1247	0	20	57	121	12	1	0	ok
1549	2026-08-01 10:44:25.760791+00	0	0	1906	1231	0	20	57	121	14	1	0	ok
1550	2026-08-01 10:45:25.761269+00	0.29	0	1906	1244	0	20	57	122	14	1	0	ok
1551	2026-08-01 10:46:25.763262+00	0.44	0	1906	1239	0	20	57	112	15	1	0	ok
1552	2026-08-01 10:47:25.764164+00	0.36	0	1906	1246	0	20	57	118	14	1	0	ok
1553	2026-08-01 10:48:25.765521+00	0.13	0	1906	1236	0	20	57	120	18	1	0	ok
1554	2026-08-01 10:49:25.7664+00	0.1	0	1906	1234	0	20	57	120	17	1	0	ok
1555	2026-08-01 10:50:25.767143+00	0.04	0	1906	1240	0	20	57	122	19	1	0	ok
1556	2026-08-01 10:51:25.768339+00	0.01	0	1906	1239	0	20	57	121	18	1	0	ok
1557	2026-08-01 10:52:25.770598+00	0	0	1906	1234	0	20	57	122	19	1	0	ok
1558	2026-08-01 10:53:25.770979+00	0	0	1906	1232	0	20	57	120	18	1	0	ok
1559	2026-08-01 10:54:25.771271+00	0	0	1906	1237	0	20	57	120	19	1	0	ok
1560	2026-08-01 10:55:25.772339+00	0	0	1906	1239	0	20	57	121	18	1	0	ok
1561	2026-08-01 10:56:25.773464+00	0	0.5	1906	1231	0	20	57	121	19	1	0	ok
1562	2026-08-01 10:57:25.777263+00	0	0	1906	1241	0	20	57	121	18	1	0	ok
1563	2026-08-01 10:58:25.77471+00	0.16	0	1906	1232	0	20	57	122	19	1	0	ok
1564	2026-08-01 10:59:25.776893+00	0.06	0.5	1906	1233	0	20	57	121	18	1	0	ok
1565	2026-08-01 11:00:25.777167+00	0.08	0	1906	1227	0	20	57	121	19	1	0	ok
1566	2026-08-01 11:01:25.780374+00	0.03	0	1906	1234	0	20	57	121	18	1	0	ok
1567	2026-08-01 11:02:25.779353+00	0.01	0	1906	1233	0	20	57	121	19	1	0	ok
1568	2026-08-01 11:03:25.779682+00	0	0	1906	1240	0	20	57	121	17	1	0	ok
1569	2026-08-01 11:04:25.780097+00	0	0	1906	1236	0	20	57	122	18	1	0	ok
1570	2026-08-01 11:05:25.782119+00	0	0.5	1906	1235	0	20	57	121	17	1	0	ok
1571	2026-08-01 11:06:25.781274+00	0	0	1906	1240	0	20	57	121	16	1	0	ok
1572	2026-08-01 11:07:25.786816+00	0	0	1906	1236	0	20	57	122	18	1	0	ok
1573	2026-08-01 11:08:25.784826+00	0	0	1906	1235	0	20	57	122	17	1	0	ok
1574	2026-08-01 11:09:25.786088+00	0	0	1906	1239	0	20	57	121	14	1	0	ok
1575	2026-08-01 11:10:25.785699+00	0	0	1906	1243	0	20	57	122	15	1	0	ok
1576	2026-08-01 11:11:25.788884+00	0	0	1906	1234	0	20	57	121	15	1	0	ok
1577	2026-08-01 11:12:25.789907+00	0	0	1906	1240	0	20	57	123	16	1	0	ok
1578	2026-08-01 11:13:25.788236+00	0	0	1906	1239	0	20	57	122	15	1	0	ok
1579	2026-08-01 11:14:25.791927+00	0	0	1906	1245	0	20	57	122	15	1	0	ok
1580	2026-08-01 11:15:25.790644+00	0.04	0	1906	1241	0	20	57	123	13	1	0	ok
1581	2026-08-01 11:16:25.791199+00	0.01	0	1906	1246	0	20	57	123	14	1	0	ok
1582	2026-08-01 11:17:25.790196+00	0	0	1906	1239	0	20	57	124	14	1	0	ok
1583	2026-08-01 11:18:25.790991+00	0	0	1906	1246	0	20	57	123	14	1	0	ok
1584	2026-08-01 11:19:25.791152+00	0	0	1906	1247	0	20	57	123	14	1	0	ok
1585	2026-08-01 11:20:25.791683+00	0	0	1906	1246	0	20	57	123	14	1	0	ok
\.


--
-- Data for Name: system_health_alerts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_health_alerts (id, metric, severity, value, threshold, message, opened_at, closed_at) FROM stdin;
1	routers_down	warning	1	0	Router(s) unreachable: 1 (threshold > 0). Affected ISPs cannot authenticate customers.	2026-07-31 09:51:37.839908+00	2026-07-31 09:59:37.841971+00
\.


--
-- Data for Name: usage_daily; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_daily (isp_id, device_id, username, usage_day, bytes_in, bytes_out, updated_at) FROM stdin;
15c14766-aa02-4e61-be85-41b79c3ffe85	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	benard	2026-08-01	36708713	373689710	2026-08-01 11:11:01.331241+00
15c14766-aa02-4e61-be85-41b79c3ffe85	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	B31@15c14766	2026-08-01	5604914	119299586	2026-08-01 07:18:01.629299+00
15c14766-aa02-4e61-be85-41b79c3ffe85	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	B1@15c14766	2026-08-01	10771638	32755318	2026-08-01 06:39:02.118961+00
15c14766-aa02-4e61-be85-41b79c3ffe85	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	B29@15c14766	2026-08-01	1766794	12817330	2026-08-01 04:42:02.507778+00
\.


--
-- Data for Name: usage_daily_pre_fix; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_daily_pre_fix (isp_id, device_id, username, usage_day, bytes_in, bytes_out, updated_at) FROM stdin;
\.


--
-- Data for Name: usage_session_state; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_session_state (acctsessionid, acctuniqueid, username, isp_id, device_id, last_in, last_out, last_seen) FROM stdin;
\.


--
-- Data for Name: usage_session_state_v2; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_session_state_v2 (acctuniqueid, acctsessionid, username, isp_id, device_id, last_in, last_out, last_seen) FROM stdin;
491fd5006ec085399158269d02bd1e9a	800000c1	B31@15c14766	15c14766-aa02-4e61-be85-41b79c3ffe85	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	5604914	119299586	2026-08-01 07:22:02.201607+00
9439e9aaca1d0b9ebaede8988f092075	800000bc	B29@15c14766	15c14766-aa02-4e61-be85-41b79c3ffe85	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	1766794	12817330	2026-08-01 04:44:02.058175+00
ab00cec9238891896673b2401b9c0feb	800000bf	B1@15c14766	15c14766-aa02-4e61-be85-41b79c3ffe85	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	10771638	32755318	2026-08-01 06:41:01.393246+00
58f95013f0cba2fa589309c8c3a01d61	81000783	benard	15c14766-aa02-4e61-be85-41b79c3ffe85	1cb9b8d3-cf22-4f3b-8734-a05d540bd4c7	36708713	373689710	2026-08-01 11:20:02.355236+00
\.


--
-- Data for Name: verification_codes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_codes (id, isp_id, channel, target, code_hash, expires_at, attempts, consumed_at, ip, created_at, selector) FROM stdin;
1	15c14766-aa02-4e61-be85-41b79c3ffe85	email	rumalinkenterprise@gmail.com	181a6046f547370c.11320ce0ae275ad60f13908af3498aca5771db565f722992e6aac167d95a5933	2026-08-01 18:23:20.048839+00	0	2026-07-31 18:23:38.390532+00	102.205.237.69	2026-07-31 18:23:20.048839+00	bbfdff87d82b
2	15c14766-aa02-4e61-be85-41b79c3ffe85	phone	254704994652	fd76b4692d641c49.d337587e3c599b5e6eb0ce2e6860db533380e6c581d9d49c07175058bd0dc685	2026-07-31 18:33:59.471787+00	0	2026-07-31 18:24:24.014585+00	102.205.237.69	2026-07-31 18:23:59.471787+00	\N
\.


--
-- Data for Name: voucher_batches; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.voucher_batches (id, isp_id, package_id, quantity, prefix, created_at) FROM stdin;
\.


--
-- Data for Name: wan_usage_monthly; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wan_usage_monthly (id, link_id, nas_id, isp_id, "position", interface, usage_month, bytes_carried, archived_at) FROM stdin;
\.


--
-- Name: _mac_delete_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public._mac_delete_log_id_seq', 1, false);


--
-- Name: _radreply_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public._radreply_audit_id_seq', 1, false);


--
-- Name: email_provider_config_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.email_provider_config_id_seq', 1, true);


--
-- Name: nas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.nas_id_seq', 1, true);


--
-- Name: radacct_radacctid_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radacct_radacctid_seq', 5, true);


--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.radcheck_delete_audit_id_seq', 178, true);


--
-- Name: radcheck_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radcheck_id_seq', 46, true);


--
-- Name: radgroupcheck_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radgroupcheck_id_seq', 1, false);


--
-- Name: radgroupreply_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radgroupreply_id_seq', 1, false);


--
-- Name: radpostauth_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radpostauth_id_seq', 19, true);


--
-- Name: radreply_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radreply_id_seq', 18692, true);


--
-- Name: system_health_alerts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_health_alerts_id_seq', 1, true);


--
-- Name: system_health_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_health_id_seq', 1585, true);


--
-- Name: verification_codes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verification_codes_id_seq', 2, true);


--
-- Name: admins admins_email_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_email_key UNIQUE (email);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: commissions commissions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_pkey PRIMARY KEY (id);


--
-- Name: email_provider_config email_provider_config_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email_provider_config
    ADD CONSTRAINT email_provider_config_pkey PRIMARY KEY (id);


--
-- Name: hotspot_bound_devices hotspot_bound_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hotspot_bound_devices
    ADD CONSTRAINT hotspot_bound_devices_pkey PRIMARY KEY (id);


--
-- Name: hotspot_packages hotspot_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_packages
    ADD CONSTRAINT hotspot_packages_pkey PRIMARY KEY (id);


--
-- Name: hotspot_sessions hotspot_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_sessions
    ADD CONSTRAINT hotspot_sessions_pkey PRIMARY KEY (id);


--
-- Name: hotspot_vouchers hotspot_vouchers_code_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_code_key UNIQUE (code);


--
-- Name: hotspot_vouchers hotspot_vouchers_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_pkey PRIMARY KEY (id);


--
-- Name: intasend_withdrawals intasend_withdrawals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.intasend_withdrawals
    ADD CONSTRAINT intasend_withdrawals_pkey PRIMARY KEY (id);


--
-- Name: isp_captive_portal isp_captive_portal_isp_id_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_captive_portal
    ADD CONSTRAINT isp_captive_portal_isp_id_key UNIQUE (isp_id);


--
-- Name: isp_captive_portal isp_captive_portal_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_captive_portal
    ADD CONSTRAINT isp_captive_portal_pkey PRIMARY KEY (id);


--
-- Name: isp_payment_methods isp_payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_payment_methods
    ADD CONSTRAINT isp_payment_methods_pkey PRIMARY KEY (id);


--
-- Name: isp_platform_invoices isp_platform_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_platform_invoices
    ADD CONSTRAINT isp_platform_invoices_pkey PRIMARY KEY (id);


--
-- Name: isp_transactions isp_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_transactions
    ADD CONSTRAINT isp_transactions_pkey PRIMARY KEY (id);


--
-- Name: isps isps_email_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isps
    ADD CONSTRAINT isps_email_key UNIQUE (email);


--
-- Name: isps isps_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isps
    ADD CONSTRAINT isps_pkey PRIMARY KEY (id);


--
-- Name: mac_auth_cache mac_auth_cache_mac_address_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mac_auth_cache
    ADD CONSTRAINT mac_auth_cache_mac_address_key UNIQUE (mac_address);


--
-- Name: mac_auth_cache mac_auth_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mac_auth_cache
    ADD CONSTRAINT mac_auth_cache_pkey PRIMARY KEY (id);


--
-- Name: mpesa_configs mpesa_configs_isp_id_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_configs
    ADD CONSTRAINT mpesa_configs_isp_id_key UNIQUE (isp_id);


--
-- Name: mpesa_configs mpesa_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_configs
    ADD CONSTRAINT mpesa_configs_pkey PRIMARY KEY (id);


--
-- Name: mpesa_transactions mpesa_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_transactions
    ADD CONSTRAINT mpesa_transactions_pkey PRIMARY KEY (id);


--
-- Name: nas_devices nas_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_devices
    ADD CONSTRAINT nas_devices_pkey PRIMARY KEY (id);


--
-- Name: nas_events nas_events_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_events
    ADD CONSTRAINT nas_events_pkey PRIMARY KEY (id);


--
-- Name: nas nas_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas
    ADD CONSTRAINT nas_pkey PRIMARY KEY (id);


--
-- Name: nas_wan_links nas_wan_links_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_links
    ADD CONSTRAINT nas_wan_links_pkey PRIMARY KEY (id);


--
-- Name: nas_wan_policies nas_wan_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_policies
    ADD CONSTRAINT nas_wan_policies_pkey PRIMARY KEY (id);


--
-- Name: nasreload nasreload_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nasreload
    ADD CONSTRAINT nasreload_pkey PRIMARY KEY (nasipaddress);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: payment_provider_configs payment_provider_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payment_provider_configs
    ADD CONSTRAINT payment_provider_configs_pkey PRIMARY KEY (id);


--
-- Name: payment_provider_configs payment_provider_configs_provider_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payment_provider_configs
    ADD CONSTRAINT payment_provider_configs_provider_key UNIQUE (provider);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: platform_secrets platform_secrets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.platform_secrets
    ADD CONSTRAINT platform_secrets_pkey PRIMARY KEY (key);


--
-- Name: platform_settings platform_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.platform_settings
    ADD CONSTRAINT platform_settings_pkey PRIMARY KEY (key);


--
-- Name: pppoe_invoices pppoe_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_pkey PRIMARY KEY (id);


--
-- Name: pppoe_packages pppoe_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_packages
    ADD CONSTRAINT pppoe_packages_pkey PRIMARY KEY (id);


--
-- Name: pppoe_sessions pppoe_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_sessions
    ADD CONSTRAINT pppoe_sessions_pkey PRIMARY KEY (id);


--
-- Name: pppoe_subscribers pppoe_subscribers_isp_id_username_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_isp_id_username_key UNIQUE (isp_id, username);


--
-- Name: pppoe_subscribers pppoe_subscribers_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_pkey PRIMARY KEY (id);


--
-- Name: radacct radacct_acctuniqueid_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radacct
    ADD CONSTRAINT radacct_acctuniqueid_key UNIQUE (acctuniqueid);


--
-- Name: radacct radacct_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radacct
    ADD CONSTRAINT radacct_pkey PRIMARY KEY (radacctid);


--
-- Name: radcheck_delete_audit radcheck_delete_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.radcheck_delete_audit
    ADD CONSTRAINT radcheck_delete_audit_pkey PRIMARY KEY (id);


--
-- Name: radcheck radcheck_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radcheck
    ADD CONSTRAINT radcheck_pkey PRIMARY KEY (id);


--
-- Name: radgroupcheck radgroupcheck_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radgroupcheck
    ADD CONSTRAINT radgroupcheck_pkey PRIMARY KEY (id);


--
-- Name: radgroupreply radgroupreply_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radgroupreply
    ADD CONSTRAINT radgroupreply_pkey PRIMARY KEY (id);


--
-- Name: radpostauth radpostauth_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radpostauth
    ADD CONSTRAINT radpostauth_pkey PRIMARY KEY (id);


--
-- Name: radreply radreply_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.radreply
    ADD CONSTRAINT radreply_pkey PRIMARY KEY (id);


--
-- Name: shop_categories shop_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_categories
    ADD CONSTRAINT shop_categories_pkey PRIMARY KEY (id);


--
-- Name: shop_categories shop_categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_categories
    ADD CONSTRAINT shop_categories_slug_key UNIQUE (slug);


--
-- Name: shop_order_items shop_order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_order_items
    ADD CONSTRAINT shop_order_items_pkey PRIMARY KEY (id);


--
-- Name: shop_orders shop_orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_orders
    ADD CONSTRAINT shop_orders_order_number_key UNIQUE (order_number);


--
-- Name: shop_orders shop_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_orders
    ADD CONSTRAINT shop_orders_pkey PRIMARY KEY (id);


--
-- Name: shop_payments shop_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_payments
    ADD CONSTRAINT shop_payments_pkey PRIMARY KEY (id);


--
-- Name: shop_products shop_products_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_products
    ADD CONSTRAINT shop_products_pkey PRIMARY KEY (id);


--
-- Name: shop_settings shop_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_settings
    ADD CONSTRAINT shop_settings_pkey PRIMARY KEY (id);


--
-- Name: sms_credit_transactions sms_credit_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_credit_transactions
    ADD CONSTRAINT sms_credit_transactions_pkey PRIMARY KEY (id);


--
-- Name: sms_logs sms_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_logs
    ADD CONSTRAINT sms_logs_pkey PRIMARY KEY (id);


--
-- Name: sms_provider_config sms_provider_config_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_provider_config
    ADD CONSTRAINT sms_provider_config_pkey PRIMARY KEY (id);


--
-- Name: support_replies support_replies_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_replies
    ADD CONSTRAINT support_replies_pkey PRIMARY KEY (id);


--
-- Name: support_tickets support_tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_tickets
    ADD CONSTRAINT support_tickets_pkey PRIMARY KEY (id);


--
-- Name: system_health_alerts system_health_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_health_alerts
    ADD CONSTRAINT system_health_alerts_pkey PRIMARY KEY (id);


--
-- Name: system_health system_health_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_health
    ADD CONSTRAINT system_health_pkey PRIMARY KEY (id);


--
-- Name: usage_daily usage_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_daily
    ADD CONSTRAINT usage_daily_pkey PRIMARY KEY (isp_id, username, usage_day, device_id);


--
-- Name: usage_session_state usage_session_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_session_state
    ADD CONSTRAINT usage_session_state_pkey PRIMARY KEY (acctsessionid);


--
-- Name: usage_session_state_v2 usage_session_state_v2_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_session_state_v2
    ADD CONSTRAINT usage_session_state_v2_pkey PRIMARY KEY (acctuniqueid);


--
-- Name: verification_codes verification_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_codes
    ADD CONSTRAINT verification_codes_pkey PRIMARY KEY (id);


--
-- Name: voucher_batches voucher_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.voucher_batches
    ADD CONSTRAINT voucher_batches_pkey PRIMARY KEY (id);


--
-- Name: wan_usage_monthly wan_usage_monthly_link_id_usage_month_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wan_usage_monthly
    ADD CONSTRAINT wan_usage_monthly_link_id_usage_month_key UNIQUE (link_id, usage_month);


--
-- Name: wan_usage_monthly wan_usage_monthly_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wan_usage_monthly
    ADD CONSTRAINT wan_usage_monthly_pkey PRIMARY KEY (id);


--
-- Name: commissions_payment_id_uidx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE UNIQUE INDEX commissions_payment_id_uidx ON public.commissions USING btree (payment_id);


--
-- Name: hbd_isp_mac_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX hbd_isp_mac_uniq ON public.hotspot_bound_devices USING btree (isp_id, upper(mac_address));


--
-- Name: hotspot_bound_devices_isp_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX hotspot_bound_devices_isp_idx ON public.hotspot_bound_devices USING btree (isp_id);


--
-- Name: hotspot_bound_devices_isp_mac_uidx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX hotspot_bound_devices_isp_mac_uidx ON public.hotspot_bound_devices USING btree (isp_id, lower(mac_address));


--
-- Name: hv_isp_phone_norm; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX hv_isp_phone_norm ON public.hotspot_vouchers USING btree (isp_id, "right"(regexp_replace((buyer_phone)::text, '[^0-9]'::text, ''::text, 'g'::text), 9)) WHERE (is_tv IS NOT TRUE);


--
-- Name: idx_captive_portal_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_captive_portal_isp ON public.isp_captive_portal USING btree (isp_id);


--
-- Name: idx_hotspot_sessions_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_hotspot_sessions_status ON public.hotspot_sessions USING btree (status);


--
-- Name: idx_isp_captive_portal_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isp_captive_portal_isp ON public.isp_captive_portal USING btree (isp_id);


--
-- Name: idx_isp_cp_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isp_cp_isp ON public.isp_captive_portal USING btree (isp_id);


--
-- Name: idx_isp_payment_methods_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isp_payment_methods_isp ON public.isp_payment_methods USING btree (isp_id);


--
-- Name: idx_isp_pm_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isp_pm_isp ON public.isp_payment_methods USING btree (isp_id);


--
-- Name: idx_isps_api_key; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isps_api_key ON public.isps USING btree (api_key);


--
-- Name: idx_isps_email; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isps_email ON public.isps USING btree (email);


--
-- Name: idx_isps_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_isps_status ON public.isps USING btree (status);


--
-- Name: idx_isw_isp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_isw_isp ON public.intasend_withdrawals USING btree (isp_id, created_at DESC);


--
-- Name: idx_isw_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_isw_status ON public.intasend_withdrawals USING btree (status);


--
-- Name: idx_mac_cache_active; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_mac_cache_active ON public.mac_auth_cache USING btree (is_active, expires_at);


--
-- Name: idx_mac_cache_mac; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_mac_cache_mac ON public.mac_auth_cache USING btree (mac_address);


--
-- Name: idx_nas_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_nas_isp ON public.nas_devices USING btree (isp_id);


--
-- Name: idx_nas_token; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_nas_token ON public.nas_devices USING btree (provision_token);


--
-- Name: idx_nas_wan_links_nas_id; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_nas_wan_links_nas_id ON public.nas_wan_links USING btree (nas_id);


--
-- Name: idx_nas_wan_policies_nas_id; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_nas_wan_policies_nas_id ON public.nas_wan_policies USING btree (nas_id);


--
-- Name: idx_notif_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_notif_isp ON public.notifications USING btree (isp_id);


--
-- Name: idx_pay_clearing; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_pay_clearing ON public.payments USING btree (payment_gateway, status, clearing_status);


--
-- Name: idx_payment_methods_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payment_methods_isp ON public.isp_payment_methods USING btree (isp_id);


--
-- Name: idx_payments_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_isp ON public.payments USING btree (isp_id);


--
-- Name: idx_payments_isp_created; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_isp_created ON public.payments USING btree (isp_id, created_at DESC);


--
-- Name: idx_payments_mpesa_phone; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_mpesa_phone ON public.payments USING btree (mpesa_phone);


--
-- Name: idx_payments_phone_number; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_phone_number ON public.payments USING btree (phone_number);


--
-- Name: idx_payments_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_payments_status ON public.payments USING btree (status);


--
-- Name: idx_pppoe_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_pppoe_isp ON public.pppoe_subscribers USING btree (isp_id);


--
-- Name: idx_pppoe_sessions_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_pppoe_sessions_status ON public.pppoe_sessions USING btree (status);


--
-- Name: idx_pppoe_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_pppoe_username ON public.pppoe_subscribers USING btree (username);


--
-- Name: idx_radacct_active; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_active ON public.radacct USING btree (acctstoptime) WHERE (acctstoptime IS NULL);


--
-- Name: idx_radacct_nas; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_nas ON public.radacct USING btree (nasipaddress);


--
-- Name: idx_radacct_session; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_session ON public.radacct USING btree (acctsessionid);


--
-- Name: idx_radacct_starttime; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_starttime ON public.radacct USING btree (acctstarttime);


--
-- Name: idx_radacct_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radacct_username ON public.radacct USING btree (username);


--
-- Name: idx_radcheck_user; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radcheck_user ON public.radcheck USING btree (username);


--
-- Name: idx_radcheck_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radcheck_username ON public.radcheck USING btree (username);


--
-- Name: idx_radpostauth_date; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radpostauth_date ON public.radpostauth USING btree (authdate);


--
-- Name: idx_radpostauth_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radpostauth_username ON public.radpostauth USING btree (username);


--
-- Name: idx_radreply_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_radreply_username ON public.radreply USING btree (username);


--
-- Name: idx_shop_order_items_order; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_order_items_order ON public.shop_order_items USING btree (order_id);


--
-- Name: idx_shop_orders_checkout; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_orders_checkout ON public.shop_orders USING btree (mpesa_checkout_id);


--
-- Name: idx_shop_orders_created; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_orders_created ON public.shop_orders USING btree (created_at DESC);


--
-- Name: idx_shop_orders_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_orders_status ON public.shop_orders USING btree (status);


--
-- Name: idx_shop_payments_checkout; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_payments_checkout ON public.shop_payments USING btree (mpesa_checkout_id);


--
-- Name: idx_shop_payments_order; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_payments_order ON public.shop_payments USING btree (order_id);


--
-- Name: idx_shop_products_active; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_products_active ON public.shop_products USING btree (is_active);


--
-- Name: idx_shop_products_category; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_shop_products_category ON public.shop_products USING btree (category_id);


--
-- Name: idx_sms_credit_created; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_sms_credit_created ON public.sms_credit_transactions USING btree (created_at);


--
-- Name: idx_sms_credit_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_sms_credit_isp ON public.sms_credit_transactions USING btree (isp_id);


--
-- Name: idx_sms_credit_type; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_sms_credit_type ON public.sms_credit_transactions USING btree (txn_type);


--
-- Name: idx_sys_alerts_open; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sys_alerts_open ON public.system_health_alerts USING btree (closed_at) WHERE (closed_at IS NULL);


--
-- Name: idx_sys_health_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sys_health_time ON public.system_health USING btree (sampled_at DESC);


--
-- Name: idx_usage_daily_device_day; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usage_daily_device_day ON public.usage_daily USING btree (device_id, usage_day);


--
-- Name: idx_usage_daily_isp_day; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usage_daily_isp_day ON public.usage_daily USING btree (isp_id, usage_day);


--
-- Name: idx_uss2_last_seen; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_uss2_last_seen ON public.usage_session_state_v2 USING btree (last_seen);


--
-- Name: idx_vouchers_code; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_vouchers_code ON public.hotspot_vouchers USING btree (code);


--
-- Name: idx_vouchers_isp; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_vouchers_isp ON public.hotspot_vouchers USING btree (isp_id);


--
-- Name: idx_vouchers_purchased_mac; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_vouchers_purchased_mac ON public.hotspot_vouchers USING btree (isp_id, upper((purchased_by_mac)::text));


--
-- Name: idx_vouchers_status; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX idx_vouchers_status ON public.hotspot_vouchers USING btree (status);


--
-- Name: idx_wum_month; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_wum_month ON public.wan_usage_monthly USING btree (usage_month);


--
-- Name: nas_nasname; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX nas_nasname ON public.nas USING btree (nasname);


--
-- Name: radacct_active_session_idx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radacct_active_session_idx ON public.radacct USING btree (acctuniqueid) WHERE (acctstoptime IS NULL);


--
-- Name: radacct_start_user_idx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radacct_start_user_idx ON public.radacct USING btree (acctstarttime, username);


--
-- Name: radcheck_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radcheck_username ON public.radcheck USING btree (username, attribute);


--
-- Name: radgroupcheck_groupname; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radgroupcheck_groupname ON public.radgroupcheck USING btree (groupname, attribute);


--
-- Name: radgroupreply_groupname; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radgroupreply_groupname ON public.radgroupreply USING btree (groupname, attribute);


--
-- Name: radpostauth_class_idx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radpostauth_class_idx ON public.radpostauth USING btree (class);


--
-- Name: radpostauth_username_idx; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radpostauth_username_idx ON public.radpostauth USING btree (username);


--
-- Name: radreply_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radreply_username ON public.radreply USING btree (username, attribute);


--
-- Name: radusergroup_username; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE INDEX radusergroup_username ON public.radusergroup USING btree (username);


--
-- Name: uniq_open_platform_invoice; Type: INDEX; Schema: public; Owner: rumalink_user
--

CREATE UNIQUE INDEX uniq_open_platform_invoice ON public.isp_platform_invoices USING btree (isp_id) WHERE (status = 'pending'::public.payment_status);


--
-- Name: vc_isp_channel; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vc_isp_channel ON public.verification_codes USING btree (isp_id, channel, created_at DESC);


--
-- Name: vc_selector; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vc_selector ON public.verification_codes USING btree (selector);


--
-- Name: vc_target_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vc_target_time ON public.verification_codes USING btree (target, created_at DESC);


--
-- Name: radcheck rl_radcheck_del_audit; Type: TRIGGER; Schema: public; Owner: rumalink_user
--

CREATE TRIGGER rl_radcheck_del_audit BEFORE DELETE ON public.radcheck FOR EACH ROW EXECUTE FUNCTION public.rl_audit_radcheck_delete();


--
-- Name: commissions commissions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: commissions commissions_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: hotspot_bound_devices hbd_isp_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hotspot_bound_devices
    ADD CONSTRAINT hbd_isp_fk FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: hotspot_packages hotspot_packages_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_packages
    ADD CONSTRAINT hotspot_packages_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: hotspot_packages hotspot_packages_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_packages
    ADD CONSTRAINT hotspot_packages_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: hotspot_sessions hotspot_sessions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_sessions
    ADD CONSTRAINT hotspot_sessions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: hotspot_sessions hotspot_sessions_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_sessions
    ADD CONSTRAINT hotspot_sessions_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: hotspot_sessions hotspot_sessions_voucher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_sessions
    ADD CONSTRAINT hotspot_sessions_voucher_id_fkey FOREIGN KEY (voucher_id) REFERENCES public.hotspot_vouchers(id);


--
-- Name: hotspot_vouchers hotspot_vouchers_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: hotspot_vouchers hotspot_vouchers_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: hotspot_vouchers hotspot_vouchers_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.hotspot_vouchers
    ADD CONSTRAINT hotspot_vouchers_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.hotspot_packages(id);


--
-- Name: intasend_withdrawals intasend_withdrawals_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.intasend_withdrawals
    ADD CONSTRAINT intasend_withdrawals_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: isp_captive_portal isp_captive_portal_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_captive_portal
    ADD CONSTRAINT isp_captive_portal_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: isp_payment_methods isp_payment_methods_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_payment_methods
    ADD CONSTRAINT isp_payment_methods_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: isp_platform_invoices isp_platform_invoices_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_platform_invoices
    ADD CONSTRAINT isp_platform_invoices_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: isp_platform_invoices isp_platform_invoices_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_platform_invoices
    ADD CONSTRAINT isp_platform_invoices_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: isp_transactions isp_transactions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.isp_transactions
    ADD CONSTRAINT isp_transactions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: mac_auth_cache mac_auth_cache_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mac_auth_cache
    ADD CONSTRAINT mac_auth_cache_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: mac_auth_cache mac_auth_cache_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mac_auth_cache
    ADD CONSTRAINT mac_auth_cache_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.hotspot_packages(id) ON DELETE SET NULL;


--
-- Name: mpesa_configs mpesa_configs_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_configs
    ADD CONSTRAINT mpesa_configs_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: mpesa_transactions mpesa_transactions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_transactions
    ADD CONSTRAINT mpesa_transactions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: mpesa_transactions mpesa_transactions_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.mpesa_transactions
    ADD CONSTRAINT mpesa_transactions_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: nas_devices nas_devices_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_devices
    ADD CONSTRAINT nas_devices_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: nas_events nas_events_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_events
    ADD CONSTRAINT nas_events_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: nas_events nas_events_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_events
    ADD CONSTRAINT nas_events_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE CASCADE;


--
-- Name: nas_wan_links nas_wan_links_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_links
    ADD CONSTRAINT nas_wan_links_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE CASCADE;


--
-- Name: nas_wan_policies nas_wan_policies_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_policies
    ADD CONSTRAINT nas_wan_policies_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE CASCADE;


--
-- Name: nas_wan_policies nas_wan_policies_target_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.nas_wan_policies
    ADD CONSTRAINT nas_wan_policies_target_link_id_fkey FOREIGN KEY (target_link_id) REFERENCES public.nas_wan_links(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.admins(id);


--
-- Name: notifications notifications_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: payments payments_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: payments payments_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.pppoe_subscribers(id);


--
-- Name: payments payments_voucher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_voucher_id_fkey FOREIGN KEY (voucher_id) REFERENCES public.hotspot_vouchers(id);


--
-- Name: pppoe_invoices pppoe_invoices_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: pppoe_invoices pppoe_invoices_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.pppoe_packages(id);


--
-- Name: pppoe_invoices pppoe_invoices_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: pppoe_invoices pppoe_invoices_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_invoices
    ADD CONSTRAINT pppoe_invoices_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.pppoe_subscribers(id);


--
-- Name: pppoe_packages pppoe_packages_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_packages
    ADD CONSTRAINT pppoe_packages_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: pppoe_sessions pppoe_sessions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_sessions
    ADD CONSTRAINT pppoe_sessions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: pppoe_sessions pppoe_sessions_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_sessions
    ADD CONSTRAINT pppoe_sessions_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: pppoe_sessions pppoe_sessions_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_sessions
    ADD CONSTRAINT pppoe_sessions_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.pppoe_subscribers(id);


--
-- Name: pppoe_subscribers pppoe_subscribers_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: pppoe_subscribers pppoe_subscribers_nas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_nas_id_fkey FOREIGN KEY (nas_id) REFERENCES public.nas_devices(id) ON DELETE SET NULL;


--
-- Name: pppoe_subscribers pppoe_subscribers_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.pppoe_subscribers
    ADD CONSTRAINT pppoe_subscribers_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.pppoe_packages(id);


--
-- Name: shop_order_items shop_order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_order_items
    ADD CONSTRAINT shop_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.shop_orders(id) ON DELETE CASCADE;


--
-- Name: shop_order_items shop_order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_order_items
    ADD CONSTRAINT shop_order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.shop_products(id) ON DELETE SET NULL;


--
-- Name: shop_payments shop_payments_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_payments
    ADD CONSTRAINT shop_payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.shop_orders(id) ON DELETE CASCADE;


--
-- Name: shop_products shop_products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.shop_products
    ADD CONSTRAINT shop_products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.shop_categories(id) ON DELETE SET NULL;


--
-- Name: sms_credit_transactions sms_credit_transactions_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_credit_transactions
    ADD CONSTRAINT sms_credit_transactions_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: sms_logs sms_logs_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.sms_logs
    ADD CONSTRAINT sms_logs_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: support_replies support_replies_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_replies
    ADD CONSTRAINT support_replies_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.support_tickets(id);


--
-- Name: support_tickets support_tickets_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_tickets
    ADD CONSTRAINT support_tickets_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.admins(id);


--
-- Name: support_tickets support_tickets_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.support_tickets
    ADD CONSTRAINT support_tickets_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id);


--
-- Name: verification_codes verification_codes_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_codes
    ADD CONSTRAINT verification_codes_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: voucher_batches voucher_batches_isp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.voucher_batches
    ADD CONSTRAINT voucher_batches_isp_id_fkey FOREIGN KEY (isp_id) REFERENCES public.isps(id) ON DELETE CASCADE;


--
-- Name: voucher_batches voucher_batches_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rumalink_user
--

ALTER TABLE ONLY public.voucher_batches
    ADD CONSTRAINT voucher_batches_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.hotspot_packages(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO rumalink_user;


--
-- Name: TABLE _mac_delete_log; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public._mac_delete_log TO rumalink_user;


--
-- Name: SEQUENCE _mac_delete_log_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public._mac_delete_log_id_seq TO rumalink_user;


--
-- Name: TABLE email_provider_config; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.email_provider_config TO rumalink_user;


--
-- Name: SEQUENCE email_provider_config_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.email_provider_config_id_seq TO rumalink_user;


--
-- Name: TABLE hotspot_bound_devices; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.hotspot_bound_devices TO rumalink_user;


--
-- Name: TABLE intasend_withdrawals; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.intasend_withdrawals TO rumalink_user;


--
-- Name: TABLE platform_secrets; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.platform_secrets TO rumalink_user;


--
-- Name: TABLE radcheck_delete_audit; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.radcheck_delete_audit TO rumalink_user;


--
-- Name: SEQUENCE radcheck_delete_audit_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.radcheck_delete_audit_id_seq TO rumalink_user;


--
-- Name: TABLE system_health; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.system_health TO rumalink_user;


--
-- Name: TABLE system_health_alerts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.system_health_alerts TO rumalink_user;


--
-- Name: SEQUENCE system_health_alerts_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.system_health_alerts_id_seq TO rumalink_user;


--
-- Name: SEQUENCE system_health_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.system_health_id_seq TO rumalink_user;


--
-- Name: TABLE usage_daily; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usage_daily TO rumalink_user;


--
-- Name: TABLE usage_daily_pre_fix; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usage_daily_pre_fix TO rumalink_user;


--
-- Name: TABLE usage_session_state; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usage_session_state TO rumalink_user;


--
-- Name: TABLE usage_session_state_v2; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usage_session_state_v2 TO rumalink_user;


--
-- Name: TABLE verification_codes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.verification_codes TO rumalink_user;


--
-- Name: SEQUENCE verification_codes_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.verification_codes_id_seq TO rumalink_user;


--
-- Name: TABLE wan_usage_monthly; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.wan_usage_monthly TO rumalink_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO rumalink_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO rumalink_user;


--
-- PostgreSQL database dump complete
--

\unrestrict TLBcRAxtoAfpE0skrMbcnwEQajWShuf26cyAnQo35eRSVXcCrHIgQRMrNfTV0rQ

