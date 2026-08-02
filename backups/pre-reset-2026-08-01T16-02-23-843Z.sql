--
-- PostgreSQL database dump
--

\restrict HOzOg6QpcSaLoZ46w2Bu50Tr1SDcxdSL3Xx2YN1DJeGdVAffcbwxFwaLCgaqRSE

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
e0556dcb-b203-4e85-b0c4-bd657bddcf62	RumaLink Admin	admin@rumalink.co.ke	$2a$12$lW4s6qSv6dP4ZBV4CMkUq.hwqqCiaphkhsZ6qELmJdG7MwF1axeje	superadmin	t	2026-08-01 16:02:04.543595+00	2026-05-24 08:18:35.982073+00	2026-05-24 08:18:35.982073+00
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
ac0d36da-dc07-40b0-8141-f55ea9daa07f	4ed565d4-36d3-4612-90cd-c2fe76cf2314	d531deca-fe82-412e-8132-a9a9fee59b47	0.15	0.0300	\N	\N	f	\N	2026-08-01 11:42:00.086928+00
2031915a-9fc5-4766-b59d-0e9459e53a9f	4ed565d4-36d3-4612-90cd-c2fe76cf2314	44196c3a-c8de-4c00-a414-8158fcc81ed6	0.15	0.0300	\N	\N	f	\N	2026-08-01 11:52:00.715191+00
8db47036-b3e5-40ad-8b15-a4dea81ced32	4ed565d4-36d3-4612-90cd-c2fe76cf2314	54c8066e-55d5-4664-8236-dbf68e160126	0.00	0.0300	\N	\N	f	\N	2026-08-01 11:58:15.869098+00
dfa885dc-2b48-42f5-9ae0-3384a7e65c5c	4ed565d4-36d3-4612-90cd-c2fe76cf2314	e2c3680f-7420-495a-ab54-510542b7d73b	0.15	0.0300	\N	\N	f	\N	2026-08-01 13:05:00.468595+00
6c542372-b27e-4d2d-b4c8-5ace55e4cd7c	4ed565d4-36d3-4612-90cd-c2fe76cf2314	7fd56259-5910-49d4-b325-85400e61414e	0.15	0.0300	\N	\N	f	\N	2026-08-01 13:54:00.267372+00
d2dd9923-f52f-49bf-86da-7f307b6791f4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	88c14dc4-7a4b-4ce6-b22e-424e5c396d8a	0.15	0.0300	\N	\N	f	\N	2026-08-01 14:09:00.77425+00
368a62db-9879-417a-8f5a-2965c54763cf	4ed565d4-36d3-4612-90cd-c2fe76cf2314	d8d70949-5d23-4e7f-8d6a-776824eeffb5	0.15	0.0300	\N	\N	f	\N	2026-08-01 14:21:00.331019+00
b5478798-91ee-4c52-b40a-769671d383bb	4ed565d4-36d3-4612-90cd-c2fe76cf2314	f4d665ff-bd12-489c-aad9-d6f3f2291176	0.15	0.0300	\N	\N	f	\N	2026-08-01 14:31:00.066947+00
c1d93b3c-dd8d-4f5a-ab33-4e2b9012dba4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	ffb90312-3e40-4c49-9290-24d80d8c21cb	0.15	0.0300	\N	\N	f	\N	2026-08-01 14:33:00.152463+00
71790eb9-eaea-443e-b6ef-f3a3b9c74a82	4ed565d4-36d3-4612-90cd-c2fe76cf2314	28304bdd-4030-452c-b746-87026ca9e425	0.15	0.0300	\N	\N	f	\N	2026-08-01 14:35:00.128644+00
30f6cbb6-8897-4ddc-a0e2-f639b45e7291	4ed565d4-36d3-4612-90cd-c2fe76cf2314	71eebeb1-4390-461c-b12f-b7bbe759e818	0.15	0.0300	\N	\N	f	\N	2026-08-01 14:41:00.14071+00
f200fc1c-4b0e-462a-9550-2d64d340cc91	4ed565d4-36d3-4612-90cd-c2fe76cf2314	cfe850b6-2777-491e-a720-79c4b57a5ae2	0.15	0.0300	\N	\N	f	\N	2026-08-01 14:46:00.282539+00
5c5d7546-72a4-4490-882a-3b50ab09af33	4ed565d4-36d3-4612-90cd-c2fe76cf2314	a9688bc8-ea5f-4ad5-89ad-9d2c0f488b06	0.15	0.0300	\N	\N	f	\N	2026-08-01 15:03:00.591835+00
06106444-bb28-43cd-a90e-e907fb663000	4ed565d4-36d3-4612-90cd-c2fe76cf2314	edd78912-45d1-4644-9c36-267b4e6d7f21	0.15	0.0300	\N	\N	f	\N	2026-08-01 15:17:00.097632+00
0d5d3b00-fb6d-4a59-b5ee-3c5b1d7f5e0b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	7a8284cb-b04f-41aa-9c4e-ac58b87dbff4	0.15	0.0300	\N	\N	f	\N	2026-08-01 15:19:00.129374+00
51adcffb-cda5-4c4b-bb67-51b9275b6cbe	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c9668320-5322-462e-bb47-4c22085bb283	0.15	0.0300	\N	\N	f	\N	2026-08-01 15:24:00.774924+00
84438a77-efb2-4d37-8c2a-e8dbc1254709	4ed565d4-36d3-4612-90cd-c2fe76cf2314	adadf16b-a511-44b2-ab0e-8437e2b4ed1b	0.15	0.0300	\N	\N	f	\N	2026-08-01 15:26:00.82389+00
243694e2-239e-45ea-af8d-d885c0f50f0f	4ed565d4-36d3-4612-90cd-c2fe76cf2314	9d6312d0-58ae-48f5-a990-18fef7191eb1	0.15	0.0300	\N	\N	f	\N	2026-08-01 15:44:00.573898+00
15d17d98-b2ad-45f8-ae3e-202b64240df5	4ed565d4-36d3-4612-90cd-c2fe76cf2314	2ccace9c-78d2-4ff6-849c-a2a8458fea19	0.06	0.0300	\N	\N	f	\N	2026-08-01 15:47:00.659584+00
c1a8360e-9dce-40fa-9bc1-276b0bd14633	4ed565d4-36d3-4612-90cd-c2fe76cf2314	412ac9ff-d1bb-47af-8fd0-43ef12d1441c	0.06	0.0300	\N	\N	f	\N	2026-08-01 15:58:00.644663+00
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
9b768ed1-bbb0-4f93-83bf-37be79112a65	4ed565d4-36d3-4612-90cd-c2fe76cf2314	Wetv	BC:2B:02:3A:7F:7C	\N	\N	\N	c33ce805-95e3-480f-b20f-1273c1ee51cf	2026-08-01 15:32:54.31987+00	f	2026-08-01 11:50:22.152927+00	2026-08-01 14:33:10.197602+00	103744270	103792155	0	0
\.


--
-- Data for Name: hotspot_packages; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_packages (id, isp_id, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, created_at, updated_at) FROM stdin;
c33ce805-95e3-480f-b20f-1273c1ee51cf	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	1 Hour	\N	5.00	1	5	5	\N	1		t	2026-08-01 11:28:36.393609+00	2026-08-01 11:28:36.393609+00
aaed7695-ba6a-480f-be55-a4e78ed3913a	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	2 Hour	\N	2.00	2	5	5	\N	1		t	2026-08-01 15:44:43.15676+00	2026-08-01 15:44:43.15676+00
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
631bb4ae-2f3e-497c-86e6-02cb2eacece1	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c33ce805-95e3-480f-b20f-1273c1ee51cf	\N	R3	\N	active	\N	\N	\N	2026-08-03 08:41:56+00	0	0	0	f	\N	\N	\N	2026-08-01 12:05:19.925079+00	2026-08-01 12:05:19.925079+00	0704101213	f	f	\N	f	8ff3by	f	\N	t	imp_1785585919923	\N
ed0e820d-6bc5-4da2-9508-8d5b10a2e311	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c33ce805-95e3-480f-b20f-1273c1ee51cf	\N	R4	\N	active	\N	\N	\N	2026-08-06 15:51:06+00	0	0	0	f	\N	\N	\N	2026-08-01 12:05:19.933383+00	2026-08-01 12:05:19.933383+00	0704101226	f	f	\N	f	8dx365	f	\N	t	imp_1785585919923	\N
2636236c-66ef-427d-8dd4-da8260f1d909	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c33ce805-95e3-480f-b20f-1273c1ee51cf	\N	R5	\N	active	\N	\N	\N	2026-08-01 16:46:16+00	0	0	0	f	\N	\N	\N	2026-08-01 12:05:19.957999+00	2026-08-01 12:05:19.957999+00	0704714570	f	f	\N	f	ayxda7	f	\N	t	imp_1785585919923	\N
cdfef248-86b1-48eb-adb1-d2e9440bee14	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c33ce805-95e3-480f-b20f-1273c1ee51cf	\N	R7	\N	active	\N	\N	\N	2026-08-01 17:10:32+00	0	0	0	f	\N	\N	\N	2026-08-01 12:05:19.977649+00	2026-08-01 12:05:19.977649+00	0743522155	f	f	\N	f	4e65a7	f	\N	t	imp_1785585919923	\N
3d922df2-657a-40d2-b696-3893460d686b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c33ce805-95e3-480f-b20f-1273c1ee51cf	\N	R8	\N	active	\N	\N	\N	2026-08-01 16:25:47+00	0	0	0	f	\N	\N	\N	2026-08-01 12:05:19.991797+00	2026-08-01 12:05:19.991797+00	0745718578	f	f	\N	f	ya5c3x	f	\N	t	imp_1785585919923	\N
71a8ae06-dee6-451a-8f5f-51aef2e0a0b4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c33ce805-95e3-480f-b20f-1273c1ee51cf	\N	R1	\N	expired	\N	\N	\N	2026-08-01 14:29:39.396265+00	0	0	0	t	\N	\N	\N	2026-08-01 11:41:13.493301+00	2026-08-01 14:29:39.396265+00	254740258495	f	f	d8d70949-5d23-4e7f-8d6a-776824eeffb5	f	ff257f	f	\N	f	\N	66:87:6A:49:95:DA
98601ba6-2d1b-499a-809e-56b15aae95df	4ed565d4-36d3-4612-90cd-c2fe76cf2314	aaed7695-ba6a-480f-be55-a4e78ed3913a	\N	R18	\N	active	66:87:6A:49:95:DA	\N	\N	2026-08-01 17:58:08.523318+00	0	0	0	t	\N	\N	\N	2026-08-01 15:57:51.573923+00	2026-08-01 15:58:08.526673+00	254740258495	f	f	412ac9ff-d1bb-47af-8fd0-43ef12d1441c	f	cd37f2	f	\N	f	\N	\N
4dba6436-fb0a-450a-bd8e-ae90ff4c0f9d	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c33ce805-95e3-480f-b20f-1273c1ee51cf	\N	R6	\N	expired	\N	\N	\N	2026-08-01 15:06:19+00	0	0	0	f	\N	\N	\N	2026-08-01 12:05:19.969175+00	2026-08-01 15:07:00.824223+00	0112404681	f	t	\N	f	y3by6y	f	\N	t	imp_1785585919923	\N
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
03564f02-7e32-4f72-95c5-3a19f86a98a4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	mpesa_stk	4322307	4322307	7V4yYILZxVLaYRalxSX7vLNKARpAItO9YwOzlA0pCCQ4KZQ0	b0eWBg6Cv0G558cMO6OhAbAKrJJ5wDvMAybO9axDEB1ZVastiVAAjh2HKwrz0VRw	3317f5d8845fbe32c8e8435e1b79934d36ae1c303f9383b5d8a35ac36d4720b6	f	f	\N	\N	\N	\N	\N	\N	\N	till	\N	\N	t	f	t	2026-08-01 11:26:34.562175+00	2026-08-01 11:26:34.562175+00	\N	production
\.


--
-- Data for Name: isp_platform_invoices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_platform_invoices (id, isp_id, period_month, period_year, pppoe_user_count, amount_per_user, total_amount, status, due_date, paid_at, created_at, invoice_number, invoice_type, payment_id, hotspot_revenue, hotspot_fee, hotspot_rate, pppoe_fee, window_start, window_end, period_expires_at) FROM stdin;
\.


--
-- Data for Name: isp_transactions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isp_transactions (id, isp_id, type, amount, balance_before, balance_after, description, reference_id, created_at) FROM stdin;
f8d47087-2a69-4455-ac52-17dd9110c7f9	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	5.00	IntaSend payment - UH11315PHY	d531deca-fe82-412e-8132-a9a9fee59b47	2026-08-01 11:42:00.096754+00
caea2bbc-c684-4f2e-9826-3bfc5e6cb371	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	10.00	IntaSend payment - UH113160G6	44196c3a-c8de-4c00-a414-8158fcc81ed6	2026-08-01 11:52:00.724471+00
9ada6fac-d287-48a3-b37f-390ddb84b1d7	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH113169SE	e2c3680f-7420-495a-ab54-510542b7d73b	2026-08-01 13:05:00.482136+00
cee2492e-4eae-4123-83ce-0052b0e9494f	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316EJ7	7fd56259-5910-49d4-b325-85400e61414e	2026-08-01 13:54:00.272693+00
07384164-f668-47d4-aa2d-e1721d709b7a	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316EVW	88c14dc4-7a4b-4ce6-b22e-424e5c396d8a	2026-08-01 14:09:00.785734+00
05882e25-d8f7-4d57-a1e7-4110eab657bc	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316J9S	d8d70949-5d23-4e7f-8d6a-776824eeffb5	2026-08-01 14:21:00.33689+00
35cf7da7-717c-4802-887b-9034d0e65885	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316E1J	f4d665ff-bd12-489c-aad9-d6f3f2291176	2026-08-01 14:31:00.074224+00
276542cd-ff61-4a43-9e29-9b83fd0071cd	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316L41	ffb90312-3e40-4c49-9290-24d80d8c21cb	2026-08-01 14:33:00.157674+00
4e71410b-5838-46e6-80aa-c590dcc487a7	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316FJV	28304bdd-4030-452c-b746-87026ca9e425	2026-08-01 14:35:00.145153+00
ae5ce291-577d-42f2-ba99-7b276552a765	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316H29	71eebeb1-4390-461c-b12f-b7bbe759e818	2026-08-01 14:41:00.146785+00
9e786d66-0772-4eef-88d9-9560ca064097	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316P40	cfe850b6-2777-491e-a720-79c4b57a5ae2	2026-08-01 14:46:00.297309+00
4a175479-dded-4ce1-8c6d-c15ec2a02a2a	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316SCX	a9688bc8-ea5f-4ad5-89ad-9d2c0f488b06	2026-08-01 15:03:00.608414+00
edf324b0-4710-47c4-9449-4a14d5d81388	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316RCU	edd78912-45d1-4644-9c36-267b4e6d7f21	2026-08-01 15:17:00.119232+00
9d502044-c2fc-490a-add5-d442db1dc8ba	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316U71	7a8284cb-b04f-41aa-9c4e-ac58b87dbff4	2026-08-01 15:19:00.139923+00
0c41a411-616a-4432-beb0-18c50687d700	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316VU3	c9668320-5322-462e-bb47-4c22085bb283	2026-08-01 15:24:00.780853+00
cbccb9ae-0af2-4645-b0b1-ff8428e19e81	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316T1Z	adadf16b-a511-44b2-ab0e-8437e2b4ed1b	2026-08-01 15:26:00.830968+00
dbbb7490-ed69-449d-b646-269ed8d7bd5e	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	5.00	\N	\N	IntaSend payment - UH11316YMW	9d6312d0-58ae-48f5-a990-18fef7191eb1	2026-08-01 15:44:00.57838+00
c9dfad2c-c701-483d-92e4-1e16e6b5a485	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	2.00	\N	\N	IntaSend payment - UH1131705R	2ccace9c-78d2-4ff6-849c-a2a8458fea19	2026-08-01 15:47:00.670767+00
33c2fd8e-ebe4-4b7d-9a96-c86511a6d89b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	payment	2.00	\N	\N	IntaSend payment - UH113177QD	412ac9ff-d1bb-47af-8fd0-43ef12d1441c	2026-08-01 15:58:00.650824+00
\.


--
-- Data for Name: isps; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isps (id, company_name, owner_name, email, phone, password_hash, plan_type, status, county, town, address, api_key, api_secret, webhook_url, wallet_balance, commission_rate, pppoe_rate_per_user, total_earned, total_commission_paid, sms_gateway, sms_api_key, sms_sender_id, logo_url, timezone, currency, email_verified, email_verify_token, password_reset_token, password_reset_expires, trial_ends_at, last_login, created_at, updated_at, sms_username, sms_partner_id, sms_api_secret, support_number, hotspot_counter, subscription_started_at, license_expires_at, billing_window_start, license_status, billing_exempt, sms_balance, phone_verified, phone_verified_at, email_verified_at) FROM stdin;
4ed565d4-36d3-4612-90cd-c2fe76cf2314	Rumalink	Benard	rumalinkenterprise@gmail.com	0704994652	$2a$12$MiU9ZhvW2g2SGFAdbcSdhO2UhhPB81r.xZdq9R7atSfUaO0dRTtFW	both	active	Nairobi	Nairobi	\N	cbe5f241-98d8-4705-b518-14473d4ba05e	07044f214209259f03153ba13012c615bb01ee26464d67af30af3dd8b70aa759	\N	\N	0.0300	32.25	109.00	2.67	talksasa	1109|mgZZ8Ybp3dVmuZyqraO5gKV4vx8ULnFoQwQod4Oua56532b7 	TALKSASA	\N	Africa/Nairobi	KES	t	\N	\N	\N	2026-08-31 11:22:53.140782+00	2026-08-01 15:58:18.649695+00	2026-08-01 11:22:53.140782+00	2026-08-01 11:27:57.869856+00	\N	\N	\N	\N	18	\N	\N	\N	trial	f	48.0000	t	2026-08-01 11:24:03.936047+00	2026-08-01 11:23:07.523093+00
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
812ab316-ad7e-41bc-a8d4-21539ab61538	4ed565d4-36d3-4612-90cd-c2fe76cf2314	d531deca-fe82-412e-8132-a9a9fee59b47	ws_CO_01082026144113455740258495	6325-4e87-8204-fad6208bcfc52117468	\N	\N	5.00	UH11315PHY	254740258495	2026-08-01 11:41:24.286805+00	completed	\N	2026-08-01 11:41:13.485829+00
12ed8157-cdf1-49e1-b1b0-935634e9f9cc	4ed565d4-36d3-4612-90cd-c2fe76cf2314	2ccace9c-78d2-4ff6-849c-a2a8458fea19	ws_CO_01082026184605892740258495	8fe4-48ca-bd42-5cafdc6306d14999808	\N	\N	2.00	UH1131705R	254740258495	2026-08-01 15:46:25.861726+00	completed	\N	2026-08-01 15:46:05.284868+00
cc92a13b-96c2-479e-8a4c-23fa31566d68	4ed565d4-36d3-4612-90cd-c2fe76cf2314	44196c3a-c8de-4c00-a414-8158fcc81ed6	ws_CO_01082026145041402740258495	2225-4750-878c-a6bb3717aa6c6682016	\N	\N	5.00	UH113160G6	254740258495	2026-08-01 11:51:12.167842+00	completed	\N	2026-08-01 11:50:41.092403+00
40eedfe0-ea65-4a46-a12f-43b1e4857e4e	4ed565d4-36d3-4612-90cd-c2fe76cf2314	e2c3680f-7420-495a-ab54-510542b7d73b	ws_CO_01082026160422737740258495	9f15-498f-8d75-f1ac6baed10126491729	\N	\N	5.00	UH113169SE	254740258495	2026-08-01 13:04:37.709847+00	completed	\N	2026-08-01 13:04:22.45975+00
104811ac-ccae-4b45-aa06-a14741c9525a	4ed565d4-36d3-4612-90cd-c2fe76cf2314	7fd56259-5910-49d4-b325-85400e61414e	ws_CO_01082026165336632740258495	4c75-47b1-80b7-4d175a340cce5361201	\N	\N	5.00	UH11316EJ7	254740258495	2026-08-01 13:53:50.201861+00	completed	\N	2026-08-01 13:53:36.794224+00
1a8ceaac-843f-4460-bfc8-b47a437cbd33	4ed565d4-36d3-4612-90cd-c2fe76cf2314	88c14dc4-7a4b-4ce6-b22e-424e5c396d8a	ws_CO_01082026170825525740258495	26b9-428b-9d5d-a44defcfb2cc4915421	\N	\N	5.00	UH11316EVW	254740258495	2026-08-01 14:08:35.919767+00	completed	\N	2026-08-01 14:08:25.47826+00
f4154f02-f576-47dc-8730-583d7daa88ef	4ed565d4-36d3-4612-90cd-c2fe76cf2314	d8d70949-5d23-4e7f-8d6a-776824eeffb5	ws_CO_01082026172011247740258495	4c75-47b1-80b7-4d175a340cce5408575	\N	\N	5.00	UH11316J9S	254740258495	2026-08-01 14:20:20.368467+00	completed	\N	2026-08-01 14:20:11.70203+00
1d96d12d-d6f5-47b8-b14b-165edbe0ccdf	4ed565d4-36d3-4612-90cd-c2fe76cf2314	f4d665ff-bd12-489c-aad9-d6f3f2291176	ws_CO_01082026173012548740258495	29a0-4d51-8b04-cf456933339a13080949	\N	\N	5.00	UH11316E1J	254740258495	2026-08-01 14:30:21.070377+00	completed	\N	2026-08-01 14:30:12.303008+00
08a001fe-2556-4839-adc0-0874c96098da	4ed565d4-36d3-4612-90cd-c2fe76cf2314	ffb90312-3e40-4c49-9290-24d80d8c21cb	ws_CO_01082026173239326740258495	7c91-470c-b7d7-23692478c561469967	\N	\N	5.00	UH11316L41	254740258495	2026-08-01 14:32:54.321627+00	completed	\N	2026-08-01 14:32:40.050391+00
f937a92a-b860-48e5-98d5-60a3fe852981	4ed565d4-36d3-4612-90cd-c2fe76cf2314	28304bdd-4030-452c-b746-87026ca9e425	ws_CO_01082026173346551740258495	7c91-470c-b7d7-23692478c561472115	\N	\N	5.00	UH11316FJV	254740258495	2026-08-01 14:33:59.064751+00	completed	\N	2026-08-01 14:33:46.292733+00
2d8081ee-64a7-4c28-bc85-fd84c4634780	4ed565d4-36d3-4612-90cd-c2fe76cf2314	71eebeb1-4390-461c-b12f-b7bbe759e818	ws_CO_01082026173956720740258495	1054-4c1f-8028-aa9c15903a02367602	\N	\N	5.00	UH11316H29	254740258495	2026-08-01 14:40:05.664846+00	completed	\N	2026-08-01 14:39:57.006787+00
db88dbd1-18b8-4897-ba38-51603cea9deb	4ed565d4-36d3-4612-90cd-c2fe76cf2314	cfe850b6-2777-491e-a720-79c4b57a5ae2	ws_CO_01082026174528893740258495	c1ba-443c-a248-81b102f51fe75616349	\N	\N	5.00	UH11316P40	254740258495	2026-08-01 14:45:40.672112+00	completed	\N	2026-08-01 14:45:28.314224+00
5ceddcc2-d6b8-4239-86f5-d589732cad6c	4ed565d4-36d3-4612-90cd-c2fe76cf2314	a9688bc8-ea5f-4ad5-89ad-9d2c0f488b06	ws_CO_01082026180225761740258495	1f3b-4d82-81e1-8dbb29a4d5998008968	\N	\N	5.00	UH11316SCX	254740258495	2026-08-01 15:02:36.827925+00	completed	\N	2026-08-01 15:02:25.535514+00
3b05ca53-3992-4d6d-97b0-6086008290a3	4ed565d4-36d3-4612-90cd-c2fe76cf2314	edd78912-45d1-4644-9c36-267b4e6d7f21	ws_CO_01082026181611259740258495	d173-4a01-8240-6a6ea34568aa5629	\N	\N	5.00	UH11316RCU	254740258495	2026-08-01 15:16:21.873586+00	completed	\N	2026-08-01 15:16:12.050786+00
2b51b263-f711-4dff-becb-144eeda08fe4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	7a8284cb-b04f-41aa-9c4e-ac58b87dbff4	ws_CO_01082026181816736740258495	96b0-4a94-99ab-3537f21048c75330	\N	\N	5.00	UH11316U71	254740258495	2026-08-01 15:18:29.513034+00	completed	\N	2026-08-01 15:18:16.590094+00
0a651656-1aec-42b6-a8f4-2360ec0dcef9	4ed565d4-36d3-4612-90cd-c2fe76cf2314	c9668320-5322-462e-bb47-4c22085bb283	ws_CO_01082026182316242740258495	9f15-498f-8d75-f1ac6baed10126749012	\N	\N	5.00	UH11316VU3	254740258495	2026-08-01 15:23:29.107237+00	completed	\N	2026-08-01 15:23:16.086001+00
797ac584-7d3b-40db-b731-adfa85e134cc	4ed565d4-36d3-4612-90cd-c2fe76cf2314	adadf16b-a511-44b2-ab0e-8437e2b4ed1b	ws_CO_01082026182456042740258495	2ac1-4754-9302-3a7864da73ff6010844	\N	\N	5.00	UH11316T1Z	254740258495	2026-08-01 15:25:09.676191+00	completed	\N	2026-08-01 15:24:56.671221+00
8fa050fb-f019-4de9-a5fd-a91248028509	4ed565d4-36d3-4612-90cd-c2fe76cf2314	9d6312d0-58ae-48f5-a990-18fef7191eb1	ws_CO_01082026184334712740258495	6325-4e87-8204-fad6208bcfc52563748	\N	\N	5.00	UH11316YMW	254740258495	2026-08-01 15:43:43.762493+00	completed	\N	2026-08-01 15:43:34.67884+00
771c2594-469c-41d1-bfdc-f325d638a62f	4ed565d4-36d3-4612-90cd-c2fe76cf2314	412ac9ff-d1bb-47af-8fd0-43ef12d1441c	ws_CO_01082026185751689740258495	6325-4e87-8204-fad6208bcfc52596165	\N	\N	2.00	UH113177QD	254740258495	2026-08-01 15:58:08.525037+00	completed	\N	2026-08-01 15:57:51.567875+00
\.


--
-- Data for Name: nas; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas (id, nasname, shortname, type, ports, secret, server, community, description) FROM stdin;
1	10.8.0.2	DandoraPhase3	mikrotik	\N	RMLFE1969448B9D4B07	\N	\N	RumaLink auto-sync
\.


--
-- Data for Name: nas_devices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_devices (id, isp_id, name, description, nas_ip, nas_port, secret, provision_token, provision_url, is_provisioned, provisioned_at, mikrotik_identity, mikrotik_version, mikrotik_board, mikrotik_mac, wan_ip, is_online, last_seen, hotspot_enabled, pppoe_enabled, hotspot_profile, pppoe_pool, winbox_port, created_at, updated_at, antishare_enabled, antishare_max_devices, bridged_ports, bridge_ports, hotspot_interface, pppoe_interface, gateway_ip, ip_pool_start, ip_pool_end, dns_primary, dns_secondary, hotspot_network, hotspot_gateway, hotspot_pool_start, hotspot_pool_end, mikrotik_api_user, mikrotik_api_password, remote_winbox_url, provision_step, cpu_load, memory_used_mb, memory_total_mb, disk_used_mb, disk_total_mb, uptime_seconds, wan_interface, available_interfaces, wireguard_private_key, wireguard_public_key, wireguard_ip, radius_secret, winbox_proxy_port, isp_link_status, isp_link_changed_at, isp_link_last_checked, isp_link_consecutive_failures, isp_link_notifications_enabled, multi_wan_mode, wan1_interface, wan1_gateway, wan1_ping_target, wan2_interface, wan2_gateway, wan2_ping_target, multi_wan_check_interval, multi_wan_fail_threshold, lb_weight_wan1, pcc_mode, multi_wan_applied_at, wan_quality_enabled, wan_quality_latency_ms, wan_quality_jitter_ms, wan_quality_loss_pct, wan_quality_trip_count, wan_quality_recover_count, wan_type, wan_pppoe_user, wan_pppoe_pass, wan_static_ip, wan_static_gw, wan_selected, wan_quality_min_mbps) FROM stdin;
da8f681c-2936-449a-8c5a-87c5bf26fcdd	4ed565d4-36d3-4612-90cd-c2fe76cf2314	DandoraPhase3	\N	\N	3799	RMLFE1969448B9D4B07	57918f98-dc6e-4648-a0ca-2bd3f1a13b52	https://rumalinkenterprise.online/api/provision/57918f98-dc6e-4648-a0ca-2bd3f1a13b52	t	2026-08-01 11:35:03.818891+00	MikroTik	7.19.6 (stable)	RB951Ui-2HnD	pending	\N	t	2026-08-01 16:02:19.878063+00	t	t	\N	\N	20001	2026-08-01 11:34:56.632266+00	2026-08-01 16:02:19.878063+00	f	1	["ether2", "ether3", "ether4", "wlan1"]	ether3,ether4,ether5	bridge1	ether1	192.168.88.1	192.168.88.10	192.168.88.254	8.8.8.8	8.8.4.4	10.100.0.0/24	10.100.0.1	10.100.0.10	10.100.0.250	rl_da8f681c	84012237-467	rumalinkenterprise.online:20001	configured	5	62	128	22	128	0	ether2	ether1,ether2,ether3,ether4,ether5	oNElIp3K03OfaBcpFD0UDXlrbIuqu12xwEBLFXcqvG0=	WC/Ci2Ht79ap1dDyIcICFe0hdyNhljnBEVsHwXR8lR8=	10.8.0.2	RMLFE1969448B9D4B07	\N	up	\N	2026-08-01 16:02:10.484+00	0	t	failover	\N	\N	8.8.8.8	\N	\N	1.1.1.1	10	3	50	both-addresses	2026-08-01 11:37:08.055672+00	t	150	60	2	4	4	pppoe	mikrotiktest2	mikrotik2541028	\N	\N	t	3
\.


--
-- Data for Name: nas_events; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_events (id, nas_id, isp_id, event_type, message, created_at) FROM stdin;
4ca85e88-9294-480b-af83-503f13369da4	da8f681c-2936-449a-8c5a-87c5bf26fcdd	4ed565d4-36d3-4612-90cd-c2fe76cf2314	provisioned	Config imported	2026-08-01 11:35:03.851644+00
\.


--
-- Data for Name: nas_wan_links; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_wan_links (id, nas_id, "position", name, interface, gateway, ping_target, role, lb_weight, enabled, current_status, created_at, resolved_ip, resolved_gateway, last_checked_at, last_rtt, is_active, internet_ok, in_load_balance, is_failover, failover_priority, last_latency_ms, last_jitter_ms, last_loss_pct, quality_state, consec_degraded, consec_good, quality_parked, probe_verdict, probe_stage, dns_ms, connect_ms, fetch_ms, throughput_kbps, last_fetch_at, consec_fetch_fail, sample_history, consec_slow, bytes_carried, bytes_since, last_tx_bytes, last_rx_bytes, bytes_month_start, in_pool, last_mbps, tp_checked_at) FROM stdin;
f38d0d36-50a2-4406-a953-d1f8fc55fdfe	da8f681c-2936-449a-8c5a-87c5bf26fcdd	2	Link 2	ether1	\N	8.8.8.8	failover_backup	50	t	standby	2026-08-01 11:36:46.853425+00	192.168.8.6/24	192.168.8.1	2026-08-01 16:02:13.550185+00	24ms218us	f	t	f	t	2	\N	\N	\N	good	0	0	f	good	complete	\N	\N	2221	\N	2026-08-01 16:02:13.277238+00	0		0	6698221	2026-08-01 11:36:46.853425+00	2308455	5349334	\N	t	\N	\N
861f9618-33ec-487f-9014-7d9009dbff9e	da8f681c-2936-449a-8c5a-87c5bf26fcdd	1	Link 1	ether2	\N	8.8.8.8	failover_primary	50	t	online	2026-08-01 11:36:46.850627+00	172.31.4.134/32	rl-wan-pppoe	2026-08-01 16:02:13.548329+00	7ms978us	t	t	f	t	1	7.953	0.2	0	good	0	440	f	good	complete	\N	\N	1188	\N	2026-08-01 16:01:59.034154+00	0	0000000000	0	542957347	2026-08-01 11:36:46.850627+00	148516660	421279543	\N	t	\N	2026-08-01 15:58:57.716674+00
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
fead740b-470a-4d19-871a-7075e42d4d25	\N	\N	info	New ISP Registered	Rumalink has registered on the platform (both plan)	f	\N	2026-08-01 11:22:54.205382+00
61c25707-d6db-44a1-aecb-dc6113b5ee1d	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	MikroTik Connected	"DandoraPhase3" checked in. Run the import command to apply config.	f	/isp/dashboard.html	2026-08-01 11:34:56.789636+00
93a69963-25ee-4522-83f9-e93563df1739	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	MikroTik Configured	"DandoraPhase3" pulled and imported its config.	f	/isp/dashboard.html	2026-08-01 11:35:03.851736+00
0abe6cdc-dc67-4814-b4bd-6d4ba0b58224	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 11:42:00.100537+00
775bf522-d275-4447-82cc-16baf34399ca	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 11:52:00.728223+00
117a20df-d611-41ee-a1b0-3421d45a69e4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES null credited to your wallet (IntaSend).	f	\N	2026-08-01 11:58:15.873955+00
cf5575f8-36eb-4bcc-87cf-ec0ea4dad0dc	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 13:05:00.487729+00
acf45a2e-5b98-4e14-b28d-e982c4850f2a	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 13:54:00.275368+00
fe25a8b6-9de5-4bf0-b0f1-81ab8299a858	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 14:09:00.791095+00
096faf78-a814-4e3c-8669-1f2b874900f5	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 14:21:00.338658+00
df7b2b19-b61f-4c29-ad14-360a67f4fa83	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 14:31:00.077894+00
910ae9fb-0d8d-4b18-b850-75c8fccc0f84	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 14:33:00.159395+00
e2948964-92a3-4d38-83d2-a2f37bb9ad40	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 14:35:00.149455+00
237445c6-8a8f-4b55-b520-9f17d4e3ca41	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 14:41:00.149231+00
b4e50064-7cd5-4e1e-95f7-390b01eedd70	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 14:46:00.301893+00
3ea0571b-9e73-48f8-a120-42d58a969ffa	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 15:03:00.616929+00
01df544d-2dba-4d89-a594-ff89b1bda813	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 15:17:00.124237+00
485649a9-48bf-423f-8456-bfb8c820e600	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 15:19:00.144114+00
cc2415d3-9128-46c0-9ef2-3fd18cb2bdf8	\N	e0556dcb-b203-4e85-b0c4-bd657bddcf62	error	VPS CRITICAL: CPU throttled by AWS	CPU throttled by AWS: 8.96 % (threshold > 5). Burst credits are exhausted. Only a plan with more vCPUs resolves this.	f	/admin/dashboard.html	2026-08-01 15:21:02.84091+00
c42d9bd8-0134-48ad-a05d-7beebc320fc3	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 15:24:00.783037+00
367ce597-9f90-4588-b2ce-01386924afe1	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 15:26:00.835225+00
692b4b81-01b4-4d43-8633-42ef6080965c	\N	e0556dcb-b203-4e85-b0c4-bd657bddcf62	info	VPS recovered: CPU throttled by AWS	CPU throttled by AWS is back to normal (0).	f	/admin/dashboard.html	2026-08-01 15:34:39.28962+00
eee8f1cb-e962-413e-a0d5-4312c19f6ede	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 15:44:00.580101+00
b3518d48-aaba-48f5-991e-059508e2497f	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 2.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 15:47:00.673893+00
edb3a850-b6b5-461d-b084-4ae6cbf20c6b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	success	Payment Received	KES 2.00 credited to your wallet (IntaSend).	f	\N	2026-08-01 15:58:00.652589+00
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
88c14dc4-7a4b-4ce6-b22e-424e5c396d8a	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316EVW	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 14:08:35.918387+00	2026-08-01 14:08:24.0591+00	2026-08-01 14:08:24.0591+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 14:09:00.742234+00
d8d70949-5d23-4e7f-8d6a-776824eeffb5	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316J9S	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_purchase_sms": "sent"}	2026-08-01 14:20:20.36643+00	2026-08-01 14:20:10.242123+00	2026-08-01 14:20:10.242123+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 14:21:00.32789+00
54c8066e-55d5-4664-8236-dbf68e160126	4ed565d4-36d3-4612-90cd-c2fe76cf2314	1bc8317e-00be-4111-8fe1-9dc350119d1b	\N	20.00	KES	mpesa	mpesa_stk	UH11315XNB	\N	254740258495	0.00	0.0300	\N	paid	\N	PPPoE - 10Mbps	{"rl_consumed": "2026-08-01 11:58:07.989741+00", "switch_package_id": "05c68638-2598-40a3-ba7d-d6ea8e73a9eb"}	2026-08-01 11:58:07.984026+00	2026-08-01 11:57:57.614563+00	2026-08-01 11:57:57.614563+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
2ccace9c-78d2-4ff6-849c-a2a8458fea19	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	2.00	KES	mpesa	mpesa_stk	UH1131705R	\N	254740258495	0.06	0.0300	2.00	paid	\N	Hotspot - 2 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 15:46:25.859844+00	2026-08-01 15:46:04.231356+00	2026-08-01 15:46:04.231356+00	f	\N	\N	\N	254740258495	2.00	\N	\N	\N	\N	\N	2026-08-01 15:47:00.654182+00
44196c3a-c8de-4c00-a414-8158fcc81ed6	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH113160G6	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"mac": "BC:2B:02:3A:7F:7C", "is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 11:51:12.166196+00	2026-08-01 11:50:39.803441+00	2026-08-01 11:50:39.803441+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 11:52:00.708236+00
f4d665ff-bd12-489c-aad9-d6f3f2291176	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316E1J	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R9", "rl_purchase_sms": "sent"}	2026-08-01 14:30:21.068585+00	2026-08-01 14:30:11.205415+00	2026-08-01 14:30:11.205415+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 14:31:00.061542+00
71eebeb1-4390-461c-b12f-b7bbe759e818	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316H29	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R9", "rl_purchase_sms": "sent"}	2026-08-01 14:40:05.663002+00	2026-08-01 14:39:55.536007+00	2026-08-01 14:39:55.536007+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 14:41:00.136553+00
d531deca-fe82-412e-8132-a9a9fee59b47	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11315PHY	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 11:41:24.28496+00	2026-08-01 11:41:12.089046+00	2026-08-01 11:41:12.089046+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 11:42:00.073266+00
7fd56259-5910-49d4-b325-85400e61414e	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316EJ7	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 13:53:50.199732+00	2026-08-01 13:53:35.521763+00	2026-08-01 13:53:35.521763+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 13:54:00.264564+00
e2c3680f-7420-495a-ab54-510542b7d73b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH113169SE	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"mac": "BC:2B:02:3A:7F:7C", "is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 13:04:37.708062+00	2026-08-01 13:04:21.37913+00	2026-08-01 13:04:21.37913+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 13:05:00.449992+00
cfe850b6-2777-491e-a720-79c4b57a5ae2	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316P40	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R11", "rl_purchase_sms": "sent"}	2026-08-01 14:45:40.670257+00	2026-08-01 14:45:27.057843+00	2026-08-01 14:45:27.057843+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 14:46:00.26344+00
28304bdd-4030-452c-b746-87026ca9e425	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316FJV	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R10", "rl_purchase_sms": "sent"}	2026-08-01 14:33:59.062767+00	2026-08-01 14:33:45.273278+00	2026-08-01 14:33:45.273278+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 14:35:00.124998+00
ffb90312-3e40-4c49-9290-24d80d8c21cb	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316L41	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"mac": "BC:2B:02:3A:7F:7C", "is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 14:32:54.31987+00	2026-08-01 14:32:38.626703+00	2026-08-01 14:32:38.626703+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 14:33:00.148293+00
412ac9ff-d1bb-47af-8fd0-43ef12d1441c	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	2.00	KES	mpesa	mpesa_stk	UH113177QD	\N	254740258495	0.06	0.0300	2.00	paid	\N	Hotspot - 2 Hour	{"rl_purchase_sms": "sent"}	2026-08-01 15:58:08.523318+00	2026-08-01 15:57:50.292775+00	2026-08-01 15:57:50.292775+00	f	\N	\N	\N	254740258495	2.00	\N	\N	\N	\N	\N	2026-08-01 15:58:00.639955+00
adadf16b-a511-44b2-ab0e-8437e2b4ed1b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316T1Z	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 15:25:09.674345+00	2026-08-01 15:24:55.593166+00	2026-08-01 15:24:55.593166+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 15:26:00.81508+00
edd78912-45d1-4644-9c36-267b4e6d7f21	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316RCU	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 15:16:21.871733+00	2026-08-01 15:16:10.625236+00	2026-08-01 15:16:10.625236+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 15:17:00.089401+00
9d6312d0-58ae-48f5-a990-18fef7191eb1	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316YMW	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 15:43:43.76047+00	2026-08-01 15:43:33.444419+00	2026-08-01 15:43:33.444419+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 15:44:00.571143+00
7a8284cb-b04f-41aa-9c4e-ac58b87dbff4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316U71	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 15:18:29.511374+00	2026-08-01 15:18:15.550619+00	2026-08-01 15:18:15.550619+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 15:19:00.116158+00
a9688bc8-ea5f-4ad5-89ad-9d2c0f488b06	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316SCX	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 15:02:36.825824+00	2026-08-01 15:02:24.452938+00	2026-08-01 15:02:24.452938+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 15:03:00.581383+00
c9668320-5322-462e-bb47-4c22085bb283	4ed565d4-36d3-4612-90cd-c2fe76cf2314	\N	\N	5.00	KES	mpesa	mpesa_stk	UH11316VU3	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-08-01 15:23:29.105479+00	2026-08-01 15:23:04.832918+00	2026-08-01 15:23:04.832918+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-08-01 15:24:00.771228+00
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
0dd50221-1006-46c0-b70e-36087eb06250	4ed565d4-36d3-4612-90cd-c2fe76cf2314	5Mbps	\N	15.00	monthly	5	5	\N	\N	\N	\N			t	2026-08-01 11:28:59.377171+00	2026-08-01 11:28:59.377171+00
05c68638-2598-40a3-ba7d-d6ea8e73a9eb	4ed565d4-36d3-4612-90cd-c2fe76cf2314	10Mbps	\N	20.00	monthly	10	10	\N	\N	\N	\N			t	2026-08-01 11:57:24.206459+00	2026-08-01 11:57:24.206459+00
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
1bc8317e-00be-4111-8fe1-9dc350119d1b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	05c68638-2598-40a3-ba7d-d6ea8e73a9eb	\N	benard	$2a$10$Vhwz.xK9UZ5NxfspnTFEU.dklJEI5GLnqvr61e2kWo2/o/YD6pW7W	Benard	0740258495				Nairobi	\N	\N	\N	\N	active	0.00	2026-09-01 11:58:07.988+00	2026-08-01	\N	2026-08-01 11:29:41.225165+00	2026-08-01 11:58:07.991722+00	\N	f	f	\N
35f65fcf-37a1-4e92-a370-622daf7a5fac	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	Jackline	CHANGE_ME_b44499	Jackline Mwangangi	0713773260	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-03 14:35:00+00	\N	\N	2026-08-01 12:05:19.940446+00	2026-08-01 12:05:19.940446+00	\N	f	f	imp_1785585919923
456913be-527e-4a18-9d69-e59679e3917a	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	Pauline	CHANGE_ME_921a8e	Pauline Njeri	0705519292	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-09 18:02:00+00	\N	\N	2026-08-01 12:05:19.942225+00	2026-08-01 12:05:19.942225+00	\N	f	f	imp_1785585919923
76150ecf-57a1-4e61-b4f0-db943a435d7b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	Hannah	CHANGE_ME_0f1e53	Hannah Wambui	0727509143	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-23 14:31:55+00	\N	\N	2026-08-01 12:05:19.943725+00	2026-08-01 12:05:19.943725+00	\N	f	f	imp_1785585919923
63f1d1d5-f15f-44fa-8676-5bced366d120	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	miriam	CHANGE_ME_8b5d46	Miriam Wanjiku	0724145513	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-08 15:35:45+00	\N	\N	2026-08-01 12:05:19.945318+00	2026-08-01 12:05:19.945318+00	\N	f	f	imp_1785585919923
ecb94e37-dadc-460a-bb5b-11f32aee8069	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	shadrack	CHANGE_ME_f7542a	Shadrack Wanjohi	0701771261	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-14 16:28:13+00	\N	\N	2026-08-01 12:05:19.946805+00	2026-08-01 12:05:19.946805+00	\N	f	f	imp_1785585919923
451490e1-bc6f-4b67-99e9-2c450655e38d	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	lucia	CHANGE_ME_a556db	Lucia Mumbua	0720564724	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-15 09:56:35+00	\N	\N	2026-08-01 12:05:19.948296+00	2026-08-01 12:05:19.948296+00	\N	f	f	imp_1785585919923
f6cd3a0b-f2cb-4446-998e-362303c6ba9a	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	andrew	CHANGE_ME_2cad68	Andrew Mutahi	0721779330	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-16 19:19:52+00	\N	\N	2026-08-01 12:05:19.949747+00	2026-08-01 12:05:19.949747+00	\N	f	f	imp_1785585919923
60502fce-2796-4d17-94ca-af1f795db475	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	bena	CHANGE_ME_28940d	bena	\N	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-10-20 08:54:00+00	\N	\N	2026-08-01 12:05:19.951097+00	2026-08-01 12:05:19.951097+00	\N	f	f	imp_1785585919923
e86dfb2a-a7c5-488b-8221-0bbfb70e28e8	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	susan	CHANGE_ME_1b5bc6	Susan Kahugu	0723544891	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-07 20:28:27+00	\N	\N	2026-08-01 12:05:19.952602+00	2026-08-01 12:05:19.952602+00	\N	f	f	imp_1785585919923
dcb0b3e4-4b71-4045-80ba-8578e67f1cba	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	george	CHANGE_ME_0c0e16	George Maina	0722224565	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-07 19:04:31+00	\N	\N	2026-08-01 12:05:19.953933+00	2026-08-01 12:05:19.953933+00	\N	f	f	imp_1785585919923
fe466e79-6cb5-4878-a3b1-1ee507df0fc3	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	margaret	CHANGE_ME_2b5406	Margaret Mwigai	0759704517	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-03 19:22:15+00	\N	\N	2026-08-01 12:05:19.955321+00	2026-08-01 12:05:19.955321+00	\N	f	f	imp_1785585919923
b8bf7117-6a12-4cd5-b7e2-fafa7c67364b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	serah	CHANGE_ME_236af2	Serah Githiri	0742311552	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-17 14:21:51+00	\N	\N	2026-08-01 12:05:19.956644+00	2026-08-01 12:05:19.956644+00	\N	f	f	imp_1785585919923
e230459c-a7dd-497e-81fe-67029521c465	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	joseph	CHANGE_ME_c3990c	Joseph Kariuki	0722388620	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-20 16:45:24+00	\N	\N	2026-08-01 12:05:19.965007+00	2026-08-01 12:05:19.965007+00	\N	f	f	imp_1785585919923
e36229c3-1dfc-4dda-a66b-a1ecd0772493	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	timothy	CHANGE_ME_6ff362	Timothy Wanderi	0113263086	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-22 18:19:00+00	\N	\N	2026-08-01 12:05:19.966436+00	2026-08-01 12:05:19.966436+00	\N	f	f	imp_1785585919923
4de2df9f-4d34-4971-aa33-65854fb0a5dc	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	hannah2	CHANGE_ME_4ba1d9	Hannah2 Nyambura	0745938920	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-02 19:24:29+00	\N	\N	2026-08-01 12:05:19.967761+00	2026-08-01 12:05:19.967761+00	\N	f	f	imp_1785585919923
47ec2477-1e9a-4e1f-8fd1-bcb9de79e2fe	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	irene	CHANGE_ME_3076fc	Irene Wangari	0714849306	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-04 12:58:12+00	\N	\N	2026-08-01 12:05:19.976193+00	2026-08-01 12:05:19.976193+00	\N	f	f	imp_1785585919923
f53cf5a5-4c63-4747-b4df-be6c52bdb8d1	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	orpha	CHANGE_ME_c13a1c	Orpha Mutheu	0748723968	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-26 10:29:50+00	\N	\N	2026-08-01 12:05:19.985103+00	2026-08-01 12:05:19.985103+00	\N	f	f	imp_1785585919923
7ee2420c-c152-4883-a5de-938f1de1aa41	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	albert2	CHANGE_ME_3c1b52	Albert2 Macharia	0735947478	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-24 16:55:08+00	\N	\N	2026-08-01 12:05:19.98657+00	2026-08-01 12:05:19.98657+00	\N	f	f	imp_1785585919923
2546f875-fba9-49d5-800f-6adf229d4096	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	angela	CHANGE_ME_2e26ad	Angela Odhiambo	0720523121	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-26 14:49:58+00	\N	\N	2026-08-01 12:05:19.987875+00	2026-08-01 12:05:19.987875+00	\N	f	f	imp_1785585919923
1bccebc5-05fd-42d7-8070-490d830235cc	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	daniel	CHANGE_ME_c6af0d	Daniel	0725707768	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-13 19:10:00+00	\N	\N	2026-08-01 12:05:19.989196+00	2026-08-01 12:05:19.989196+00	\N	f	f	imp_1785585919923
0a3e159a-da53-4770-b943-6135bf25a108	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	mikrotiktest2	CHANGE_ME_5f280d	mikrotiktest2	01171959421	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-31 18:53:00+00	\N	\N	2026-08-01 12:05:19.990501+00	2026-08-01 12:05:19.990501+00	\N	f	f	imp_1785585919923
ebc7d466-bbba-43c8-a9fa-6caacc258329	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0dd50221-1006-46c0-b70e-36087eb06250	\N	daniel2	CHANGE_ME_f0019d	daniel2	07485236481	\N	\N	\N	\N	\N	\N	\N	\N	active	0.00	2026-08-27 18:01:00+00	\N	\N	2026-08-01 12:05:19.998723+00	2026-08-01 12:05:19.998723+00	\N	f	f	imp_1785585919923
\.


--
-- Data for Name: radacct; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radacct (radacctid, acctsessionid, acctuniqueid, username, nasipaddress, nasportid, nasporttype, acctstarttime, acctstoptime, acctinterval, acctsessiontime, acctauthentic, connectinfo_start, connectinfo_stop, acctinputoctets, acctoutputoctets, calledstationid, callingstationid, acctterminatecause, servicetype, framedprotocol, framedipaddress, acctstart_delay, acctdelivery_date, realm, acctupdatetime, framedipv6address, framedipv6prefix, framedinterfaceid, delegatedipv6prefix) FROM stdin;
13	8000002e	a9edc377682204ee099667e9cea8067e	R9@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 14:31:09+00	2026-08-01 14:31:53+00	\N	44				74504	165648	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 14:31:09.235786+00	\N	2026-08-01 14:31:53+00	\N	\N	\N	\N
2	80000019	756b5117e54d862187a649562336c82b	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 11:44:42+00	2026-08-01 11:48:48+00	120	246				60	260	rl-hotspot	66:87:6A:49:95:DA	Lost-Service			10.100.0.225	\N	2026-08-01 11:44:43.024752+00	\N	2026-08-01 11:48:48+00	\N	\N	\N	\N
24	8000003e	881e06c0c474ecea6eaec805f4f01a21	R16@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 15:43:45+00	2026-08-01 15:45:38+00	\N	113				211298	293306	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 15:43:45.916527+00	\N	2026-08-01 15:45:38+00	\N	\N	\N	\N
3	8000001b	5cb2b75fd1594370eeedafc208242777	R1@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 11:46:26+00	2026-08-01 11:49:04+00	119	158				152304	150458	rl-hotspot	66:87:6A:49:95:DA	Lost-Service			10.100.0.226	\N	2026-08-01 11:46:26.221535+00	\N	2026-08-01 11:49:04+00	\N	\N	\N	\N
21	80000037	58f44fd55b8c96daeed399f779eed388	R13@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 15:18:33+00	2026-08-01 15:22:10+00	120	217				178542	159372	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 15:18:33.669925+00	\N	2026-08-01 15:22:10+00	\N	\N	\N	\N
1	81000023	adda2de958c3db257310e6e59c59eedf	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-01 11:44:00+00	2026-08-01 11:55:11+00	301	671	RADIUS			8188835	24020786	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-01 11:44:01.01485+00	\N	2026-08-01 11:55:11+00	\N	\N	\N	\N
4	81000024	080c667d29dd4b3d5a9f6eb7cd4e9cb5	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-01 11:55:16+00	2026-08-01 11:55:45+00	\N	29	RADIUS			122331	56459	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-01 11:55:16.87148+00	\N	2026-08-01 11:55:45+00	\N	\N	\N	\N
5	81000025	af9ad27facaceed3c0390dc93cf00158	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-01 11:55:50+00	2026-08-01 11:58:15+00	\N	145	RADIUS			224984	289366	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-08-01 11:55:50.745681+00	\N	2026-08-01 11:58:15+00	\N	\N	\N	\N
14	8000002f	713f0438671eb7d154d40a5229a90381	R10@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 14:34:03+00	2026-08-01 14:39:10+00	121	306				394423	595826	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 14:34:03.759336+00	\N	2026-08-01 14:39:10+00	\N	\N	\N	\N
10	8000002b	8de2618ddfc4e433404fb12f72ed1154	R1@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 14:08:39+00	2026-08-01 14:19:50+00	120	671				451837	893272	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 14:08:39.458591+00	\N	2026-08-01 14:19:50+00	\N	\N	\N	\N
8	80000021	6739db4c818a7f8994d6bc01012eb141	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 12:09:18+00	2026-08-01 12:41:25+00	120	1926				1556997	17223420	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 12:09:18.624773+00	\N	2026-08-01 12:41:25+00	\N	\N	\N	\N
22	80000039	13833e337aa22e85527d93643071b0b8	R14@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 15:23:33+00	2026-08-01 15:24:06+00	\N	34				54856	69012	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 15:23:33.207746+00	\N	2026-08-01 15:24:06+00	\N	\N	\N	\N
15	80000030	f700064cd0d98145a7412cd9bb0cb881	R9@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 14:40:07+00	2026-08-01 14:44:59+00	120	292				699187	4874480	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 14:40:08.093827+00	\N	2026-08-01 14:44:59+00	\N	\N	\N	\N
11	8000002c	02a8d90c86a36e1121d3246d484adf51	R1@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 14:20:22+00	2026-08-01 14:29:51+00	120	569				322663	352961	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 14:20:22.541088+00	\N	2026-08-01 14:29:51+00	\N	\N	\N	\N
7	80000020	bff54a18c38359bc7f3b2feda8be3656	R2@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 12:02:54+00	2026-08-01 12:51:26+00	120	2912				929141	1289570	rl-hotspot	9E:A0:95:3A:BF:8D	Admin-Reset			10.100.0.220	\N	2026-08-01 12:02:54.282693+00	\N	2026-08-01 12:51:26+00	\N	\N	\N	\N
9	80000028	e112bd7edc5227ec1a5e1f60e185565d	R1@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 13:53:53+00	2026-08-01 14:07:02+00	120	789				636757	538165	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 13:53:53.913406+00	\N	2026-08-01 14:07:02+00	\N	\N	\N	\N
12	8000002d	7587ca69b33dde7becdc40ece0fe13af	R9@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 14:30:23+00	2026-08-01 14:30:57+00	\N	34				86926	71455	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 14:30:23.35712+00	\N	2026-08-01 14:30:57+00	\N	\N	\N	\N
16	80000031	3b508800c6d25f424f40545c6606ea92	R11@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 14:45:42+00	2026-08-01 15:01:41+00	0	959				1328464	18488351	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 14:45:42.577937+00	\N	2026-08-01 15:01:41+00	\N	\N	\N	\N
17	80000034	aa7b9410ac877ba005a0f7dcb3753d8f	R11@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 15:02:39+00	2026-08-01 15:15:45+00	120	786				332088	410069	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 15:02:39.579885+00	\N	2026-08-01 15:15:45+00	\N	\N	\N	\N
20	80000035	411942c680d7968696f60976d16e33cb	R12@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 15:16:26+00	2026-08-01 15:17:22+00	\N	57				101087	81441	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 15:16:26.18557+00	\N	2026-08-01 15:17:22+00	\N	\N	\N	\N
26	80000044	14d757e7b4b3ab7845f647d09a8ec331	R18@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 15:58:02+00	\N	120	240			\N	279743	184900	rl-hotspot	66:87:6A:49:95:DA	\N			10.100.0.215	\N	2026-08-01 15:58:02.589586+00	\N	2026-08-01 16:02:02+00	\N	\N	\N	\N
23	8000003b	9f701dcb867e62d346006d95b45c709b	R15@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 15:25:13+00	2026-08-01 15:35:38+00	120	625				213982	155826	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.225	\N	2026-08-01 15:25:13.769131+00	\N	2026-08-01 15:35:38+00	\N	\N	\N	\N
25	8000003f	8a6609cef8c88e834b998d5c5d3a74dc	R17@4ed565d4	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-08-01 15:46:19+00	2026-08-01 15:55:29+00	119	550				291117	689090	rl-hotspot	66:87:6A:49:95:DA	Lost-Service			10.100.0.225	\N	2026-08-01 15:46:19.785336+00	\N	2026-08-01 15:55:29+00	\N	\N	\N	\N
6	81000026	b7e24f01094ccdaa1ffcbb145d5d3489	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-08-01 11:58:20+00	\N	300	14400	RADIUS		\N	20248061	88464350	rumalink	50:0F:F5:36:A7:50	\N	Framed-User	PPP	100.64.0.254	\N	2026-08-01 11:58:20.430761+00	\N	2026-08-01 15:58:20+00	\N	\N	\N	\N
\.


--
-- Data for Name: radcheck; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radcheck (id, username, attribute, op, value) FROM stdin;
1	benard	Cleartext-Password	:=	benard2541028
2	benard	NT-Password	:=	0B340A7005F4C900BF15E1D362239383
12	R3@4ed565d4	Cleartext-Password	:=	8ff3by
13	R4@4ed565d4	Cleartext-Password	:=	8dx365
14	R5@4ed565d4	Cleartext-Password	:=	ayxda7
70	66:87:6A:49:95:DA	Cleartext-Password	:=	RLMACAUTH
16	R7@4ed565d4	Cleartext-Password	:=	4e65a7
17	R8@4ed565d4	Cleartext-Password	:=	ya5c3x
71	R18@4ed565d4	Cleartext-Password	:=	cd37f2
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
209	2026-08-01 14:44:03.515955+00	R9@4ed565d4		127.0.0.1	42731	DELETE FROM radcheck WHERE username = $1 OR username = $2
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
179	2026-08-01 11:42:00.108548+00	R1@4ed565d4		127.0.0.1	2034	DELETE FROM radcheck WHERE username = $1 OR username = $2
180	2026-08-01 11:51:04.166063+00	R2@4ed565d4		127.0.0.1	3200	DELETE FROM radcheck WHERE username = $1
181	2026-08-01 11:51:12.172333+00	R2@4ed565d4		127.0.0.1	3200	DELETE FROM radcheck WHERE username = $1
182	2026-08-01 11:52:03.741684+00	R2@4ed565d4		127.0.0.1	3287	DELETE FROM radcheck WHERE username = $1 OR username = $2
183	2026-08-01 12:03:24.460756+00	BC:2B:02:3A:7F:7C		127.0.0.1	4425	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
184	2026-08-01 12:41:24.476433+00	66:87:6A:49:95:DA		127.0.0.1	12980	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
185	2026-08-01 12:42:02.213858+00	R1@4ed565d4	psql	\N	13249	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
186	2026-08-01 12:47:24.477823+00	9E:A0:95:3A:BF:8D		127.0.0.1	14420	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
187	2026-08-01 12:52:01.757712+00	R2@4ed565d4	psql	\N	15621	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
188	2026-08-01 13:05:03.356397+00	R2@4ed565d4		127.0.0.1	18646	DELETE FROM radcheck WHERE username = $1 OR username = $2
189	2026-08-01 13:54:00.281701+00	R1@4ed565d4		127.0.0.1	30628	DELETE FROM radcheck WHERE username = $1 OR username = $2
190	2026-08-01 14:05:01.434335+00	R2@4ed565d4	psql	\N	33337	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
191	2026-08-01 14:06:27.729601+00	R1@4ed565d4		127.0.0.1	33531	DELETE FROM radcheck WHERE username = $1 OR username = $2
192	2026-08-01 14:06:31.472395+00	66:87:6A:49:95:DA		127.0.0.1	33532	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
193	2026-08-01 14:09:00.79696+00	R1@4ed565d4		127.0.0.1	33996	DELETE FROM radcheck WHERE username = $1 OR username = $2
194	2026-08-01 14:19:46.685541+00	R1@4ed565d4		127.0.0.1	36854	DELETE FROM radcheck WHERE username = $1 OR username = $2
195	2026-08-01 14:21:00.342408+00	R1@4ed565d4		127.0.0.1	37113	DELETE FROM radcheck WHERE username = $1 OR username = $2
196	2026-08-01 14:28:02.189997+00	R9@4ed565d4	psql	\N	38906	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
197	2026-08-01 14:29:39.398477+00	R1@4ed565d4		127.0.0.1	39329	DELETE FROM radcheck WHERE username = $1 OR username = $2
198	2026-08-01 14:29:48.892084+00	66:87:6A:49:95:DA		127.0.0.1	38879	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
199	2026-08-01 14:29:48.892084+00	66:87:6A:49:95:DA		127.0.0.1	38879	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
200	2026-08-01 14:30:56.47449+00	R9@4ed565d4		127.0.0.1	39344	DELETE FROM radcheck WHERE username = $1 OR username = $2
201	2026-08-01 14:31:24.251214+00	R9@4ed565d4		127.0.0.1	39595	DELETE FROM radcheck WHERE username = $1 OR username = $2
202	2026-08-01 14:31:48.890734+00	66:87:6A:49:95:DA		127.0.0.1	39585	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
203	2026-08-01 14:33:10.201038+00	R2@4ed565d4		127.0.0.1	40060	DELETE FROM radcheck WHERE username = $1 OR username = $2
204	2026-08-01 14:35:00.160016+00	R10@4ed565d4		127.0.0.1	40504	DELETE FROM radcheck WHERE username = $1 OR username = $2
205	2026-08-01 14:38:42.13318+00	66:87:6A:49:95:DA		127.0.0.1	41505	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
206	2026-08-01 14:39:01.846317+00	R2@4ed565d4	psql	\N	41555	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
207	2026-08-01 14:39:01.846317+00	R10@4ed565d4	psql	\N	41555	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
208	2026-08-01 14:41:00.153733+00	R9@4ed565d4		127.0.0.1	42005	DELETE FROM radcheck WHERE username = $1 OR username = $2
210	2026-08-01 14:44:59.186141+00	66:87:6A:49:95:DA		127.0.0.1	42953	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
211	2026-08-01 14:46:00.325046+00	R11@4ed565d4		127.0.0.1	42966	DELETE FROM radcheck WHERE username = $1 OR username = $2
212	2026-08-01 15:00:02.663374+00	R11@4ed565d4	psql	\N	55509	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
213	2026-08-01 15:00:02.663374+00	R10@4ed565d4	psql	\N	55509	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
214	2026-08-01 15:00:45.346654+00	66:87:6A:49:95:DA		127.0.0.1	55462	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
215	2026-08-01 15:03:00.625909+00	R11@4ed565d4		127.0.0.1	56184	DELETE FROM radcheck WHERE username = $1 OR username = $2
216	2026-08-01 15:07:02.2613+00	R6@4ed565d4	psql	\N	57177	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
217	2026-08-01 15:15:14.742399+00	R11@4ed565d4		127.0.0.1	59185	DELETE FROM radcheck WHERE username = $1 OR username = $2
218	2026-08-01 15:15:45.353164+00	66:87:6A:49:95:DA		127.0.0.1	59184	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
219	2026-08-01 15:16:53.932427+00	R12@4ed565d4		127.0.0.1	59446	DELETE FROM radcheck WHERE username = $1 OR username = $2
220	2026-08-01 15:17:34.454947+00	R12@4ed565d4		127.0.0.1	59675	DELETE FROM radcheck WHERE username = $1 OR username = $2
221	2026-08-01 15:17:45.353857+00	66:87:6A:49:95:DA		127.0.0.1	59675	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
222	2026-08-01 15:19:00.160765+00	R13@4ed565d4		127.0.0.1	59916	DELETE FROM radcheck WHERE username = $1 OR username = $2
223	2026-08-01 15:22:08.974871+00	R13@4ed565d4		127.0.0.1	60866	DELETE FROM radcheck WHERE username = $1 OR username = $2
224	2026-08-01 15:23:01.852221+00	66:87:6A:49:95:DA		127.0.0.1	60858	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
225	2026-08-01 15:24:00.606332+00	R14@4ed565d4		127.0.0.1	61329	DELETE FROM radcheck WHERE username = $1 OR username = $2
226	2026-08-01 15:24:18.566611+00	R14@4ed565d4		127.0.0.1	61334	DELETE FROM radcheck WHERE username = $1 OR username = $2
227	2026-08-01 15:25:01.746769+00	66:87:6A:49:95:DA		127.0.0.1	61554	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
228	2026-08-01 15:25:09.680755+00	R15@4ed565d4		127.0.0.1	61560	DELETE FROM radcheck WHERE username = $1
229	2026-08-01 15:26:00.840456+00	R15@4ed565d4		127.0.0.1	61799	DELETE FROM radcheck WHERE username = $1 OR username = $2
230	2026-08-01 15:35:21.933556+00	R15@4ed565d4		127.0.0.1	63949	DELETE FROM radcheck WHERE username = $1 OR username = $2
231	2026-08-01 15:35:38.262121+00	66:87:6A:49:95:DA		127.0.0.1	63952	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
232	2026-08-01 15:44:00.58338+00	R16@4ed565d4		127.0.0.1	66081	DELETE FROM radcheck WHERE username = $1 OR username = $2
233	2026-08-01 15:45:17.697243+00	R16@4ed565d4		127.0.0.1	66310	DELETE FROM radcheck WHERE username = $1 OR username = $2
234	2026-08-01 15:45:38.259492+00	66:87:6A:49:95:DA		127.0.0.1	66293	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
235	2026-08-01 15:46:25.86618+00	R17@4ed565d4		127.0.0.1	66554	DELETE FROM radcheck WHERE username = $1
236	2026-08-01 15:47:00.686401+00	R17@4ed565d4		127.0.0.1	66767	DELETE FROM radcheck WHERE username = $1 OR username = $2
237	2026-08-01 15:55:43.633723+00	66:87:6A:49:95:DA		127.0.0.1	68278	DELETE FROM radcheck WHERE username ~ '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE UPPER(v.used_by_mac)=radcheck.username AND v.status='active' AND v.expires_at>NOW() AND (v.is_tv IS NOT TRUE))
238	2026-08-01 15:56:02.373412+00	R17@4ed565d4	psql	\N	69034	DELETE FROM radcheck \nWHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K\n  AND NOT EXISTS (\n    SELECT 1 FROM hotspot_vouchers v\n    WHERE v.status IN ('unused', 'active')\n      AND (v.expires_at IS NULL OR v.expires_at > NOW())\n      AND v.code = SPLIT_PART(radcheck.username, '@', 1)\n  );
239	2026-08-01 15:58:00.656521+00	R18@4ed565d4		127.0.0.1	69516	DELETE FROM radcheck WHERE username = $1 OR username = $2
240	2026-08-01 15:58:08.529744+00	R18@4ed565d4		127.0.0.1	69522	DELETE FROM radcheck WHERE username = $1
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
1	benard		Access-Accept	2026-08-01 11:44:00.823673+00	\N
2	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-08-01 11:44:42.828834+00	\N
3	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-08-01 11:44:43.015659+00	\N
4	R1@4ed565d4	ff257f	Access-Accept	2026-08-01 11:46:26.024196+00	\N
5	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-08-01 11:49:21.068416+00	\N
6	B32@15c14766	2bf82y	Access-Reject	2026-08-01 11:49:52.651635+00	\N
7	benard		Access-Accept	2026-08-01 11:55:16.67056+00	\N
8	benard		Access-Accept	2026-08-01 11:55:50.560622+00	\N
9	benard		Access-Accept	2026-08-01 11:58:20.230089+00	\N
10	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-08-01 12:01:37.171016+00	\N
11	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-08-01 12:01:41.007488+00	\N
12	R2@4ed565d4	3d96f4	Access-Accept	2026-08-01 12:02:54.068581+00	\N
13	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-08-01 12:09:18.416847+00	\N
14	16:AA:15:6E:58:0B	RLMACAUTH	Access-Reject	2026-08-01 12:15:08.030411+00	\N
15	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 12:42:02.342344+00	\N
16	3A:AD:23:80:40:76	RLMACAUTH	Access-Reject	2026-08-01 13:12:12.059855+00	\N
17	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 13:20:12.765811+00	\N
18	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 13:31:15.648174+00	\N
19	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 13:53:05.064961+00	\N
20	R1@4ed565d4	ff257f	Access-Accept	2026-08-01 13:53:53.702686+00	\N
21	R1@4ed565d4	ff257f	Access-Reject	2026-08-01 14:07:27.342498+00	\N
22	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 14:07:54.956307+00	\N
23	R1@4ed565d4	ff257f	Access-Accept	2026-08-01 14:08:39.264867+00	\N
24	R1@4ed565d4	ff257f	Access-Accept	2026-08-01 14:20:22.332708+00	\N
25	R9@4ed565d4	y2y589	Access-Accept	2026-08-01 14:30:23.145705+00	\N
26	R9@4ed565d4	y2y589	Access-Accept	2026-08-01 14:31:09.039044+00	\N
27	R10@4ed565d4	ydxd4c	Access-Accept	2026-08-01 14:34:03.537732+00	\N
28	R9@4ed565d4	f85fbx	Access-Accept	2026-08-01 14:40:07.896949+00	\N
29	R11@4ed565d4	25847x	Access-Accept	2026-08-01 14:45:42.384323+00	\N
30	R11@4ed565d4	25847x	Access-Reject	2026-08-01 15:01:59.984905+00	\N
31	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 15:02:15.778057+00	\N
32	R11@4ed565d4	4d8fbd	Access-Accept	2026-08-01 15:02:39.386321+00	\N
33	R12@4ed565d4	ya9afb	Access-Accept	2026-08-01 15:16:25.992518+00	\N
34	R12@4ed565d4	ya9afb	Access-Reject	2026-08-01 15:17:48.403123+00	\N
35	R13@4ed565d4	34xd9x	Access-Accept	2026-08-01 15:18:33.459617+00	\N
36	R13@4ed565d4	34xd9x	Access-Reject	2026-08-01 15:22:35.447931+00	\N
37	R14@4ed565d4	x986fy	Access-Accept	2026-08-01 15:23:33.013581+00	\N
38	R14@4ed565d4	x986fy	Access-Reject	2026-08-01 15:24:33.262972+00	\N
39	R15@4ed565d4	f833cb	Access-Accept	2026-08-01 15:25:13.574465+00	\N
40	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-08-01 15:39:53.527359+00	\N
41	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-08-01 15:39:56.801081+00	\N
42	R16@4ed565d4	ef544y	Access-Accept	2026-08-01 15:43:45.703799+00	\N
43	R17@4ed565d4	af9c24	Access-Accept	2026-08-01 15:46:19.575278+00	\N
44	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-08-01 15:56:05.881955+00	\N
45	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 15:57:21.897893+00	\N
46	R17@4ed565d4	af9c24	Access-Reject	2026-08-01 15:57:26.079044+00	\N
47	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-08-01 15:57:41.351749+00	\N
48	R18@4ed565d4	cd37f2	Access-Accept	2026-08-01 15:58:02.392268+00	\N
\.


--
-- Data for Name: radreply; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radreply (id, username, attribute, op, value) FROM stdin;
140	R3@4ed565d4	Session-Timeout	:=	160596
141	R3@4ed565d4	Mikrotik-Rate-Limit	:=	5M/5M
142	R4@4ed565d4	Session-Timeout	:=	445546
143	R4@4ed565d4	Mikrotik-Rate-Limit	:=	5M/5M
144	R5@4ed565d4	Session-Timeout	:=	16856
145	R5@4ed565d4	Mikrotik-Rate-Limit	:=	5M/5M
148	R7@4ed565d4	Session-Timeout	:=	18312
149	R7@4ed565d4	Mikrotik-Rate-Limit	:=	5M/5M
150	R8@4ed565d4	Session-Timeout	:=	15627
151	R8@4ed565d4	Mikrotik-Rate-Limit	:=	5M/5M
6048	benard	Mikrotik-Rate-Limit	= 	10M/10M
6049	Jackline	Mikrotik-Rate-Limit	= 	5M/5M
6050	Pauline	Mikrotik-Rate-Limit	= 	5M/5M
6051	Hannah	Mikrotik-Rate-Limit	= 	5M/5M
6052	miriam	Mikrotik-Rate-Limit	= 	5M/5M
6053	shadrack	Mikrotik-Rate-Limit	= 	5M/5M
6054	lucia	Mikrotik-Rate-Limit	= 	5M/5M
6055	andrew	Mikrotik-Rate-Limit	= 	5M/5M
6056	bena	Mikrotik-Rate-Limit	= 	5M/5M
6057	susan	Mikrotik-Rate-Limit	= 	5M/5M
6058	george	Mikrotik-Rate-Limit	= 	5M/5M
6059	margaret	Mikrotik-Rate-Limit	= 	5M/5M
6060	serah	Mikrotik-Rate-Limit	= 	5M/5M
6061	joseph	Mikrotik-Rate-Limit	= 	5M/5M
6062	timothy	Mikrotik-Rate-Limit	= 	5M/5M
6063	hannah2	Mikrotik-Rate-Limit	= 	5M/5M
6064	irene	Mikrotik-Rate-Limit	= 	5M/5M
6065	orpha	Mikrotik-Rate-Limit	= 	5M/5M
6066	albert2	Mikrotik-Rate-Limit	= 	5M/5M
6067	angela	Mikrotik-Rate-Limit	= 	5M/5M
6068	daniel	Mikrotik-Rate-Limit	= 	5M/5M
6069	mikrotiktest2	Mikrotik-Rate-Limit	= 	5M/5M
6070	daniel2	Mikrotik-Rate-Limit	= 	5M/5M
5969	R18@4ed565d4	Session-Timeout	:=	7199
5970	R18@4ed565d4	Mikrotik-Rate-Limit	:=	5M/5M
6046	66:87:6A:49:95:DA	Session-Timeout	:=	7004
6047	66:87:6A:49:95:DA	Mikrotik-Rate-Limit	:=	5M/5M
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
15e21993-b494-4918-b6da-e7f9e2753488	4ed565d4-36d3-4612-90cd-c2fe76cf2314	signup_bonus	50.0000	\N	\N	\N	\N	50.0000	\N	completed	Welcome bonus on signup	2026-08-01 11:22:53.146371+00
1975e1e2-12ff-4354-9002-3c52ef9d4cd7	4ed565d4-36d3-4612-90cd-c2fe76cf2314	consumption	-1.0000	\N	\N	\N	\N	49.0000	\N	completed	SMS sent	2026-08-01 11:23:12.783336+00
e29ea66b-a621-4fab-817f-cd19085770d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	consumption	-1.0000	\N	\N	\N	\N	48.0000	\N	completed	SMS sent	2026-08-01 11:27:38.308437+00
\.


--
-- Data for Name: sms_logs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_logs (id, isp_id, recipient, message, gateway, gateway_message_id, status, cost, sent_at) FROM stdin;
794da9d8-09a8-4448-96b0-e1dad5326879	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254704994652	Your RumaLink verification code is 586410. It expires in 10 minutes. Do not share it.	rumalink	\N	sent	\N	2026-08-01 11:23:12.78597+00
8fda6812-7c11-4cb7-b7c5-eb77931defa4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	0740258495	RumaLink test SMS from TALKSASA. If you received this, your SMS gateway is working correctly!	rumalink	\N	sent	\N	2026-08-01 11:27:38.311051+00
6c81c299-4d6d-4a6d-9011-888326d3852d	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R1\nPassword: ff257f\nExpires: 01 Aug 2026, 15:41\nReceipt: UH11315PHY	talksasa	\N	sent	\N	2026-08-01 11:42:00.422772+00
9858a0cb-167a-459b-a2ad-2ad30973ce19	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R2\nPassword: 3d96f4\nExpires: 01 Aug 2026, 15:51\nReceipt: UH113160G6	talksasa	\N	sent	\N	2026-08-01 11:52:03.942819+00
06d5fead-4b40-4eee-aa98-0d97e6d8ad59	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated for Wetv.\nIt connects automatically — no login needed.\nExpires: 01 Aug 2026, 17:04\nReceipt: UH113169SE	talksasa	\N	sent	\N	2026-08-01 13:05:03.58366+00
f5313297-889f-4e31-91bb-578ee6dd7d49	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R1\nPassword: ff257f\nExpires: 01 Aug 2026, 17:53\nReceipt: UH11316EJ7	talksasa	\N	sent	\N	2026-08-01 13:54:00.491322+00
ca3516a8-a4a3-4784-aa12-2b001d209aac	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R1\nPassword: ff257f\nExpires: 01 Aug 2026, 18:08\nReceipt: UH11316EVW	talksasa	\N	sent	\N	2026-08-01 14:09:00.985069+00
cd40dd91-cb23-4eb9-9b79-5071436dec2b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R1\nPassword: ff257f\nExpires: 01 Aug 2026, 18:20\nReceipt: UH11316J9S	talksasa	\N	sent	\N	2026-08-01 14:21:00.567241+00
964cdd25-12eb-43ca-8468-c14d887189b1	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R9\nPassword: y2y589\nExpires: 01 Aug 2026, 18:30\nReceipt: UH11316E1J	talksasa	\N	sent	\N	2026-08-01 14:30:21.722339+00
7c67ef84-76e2-477a-8b81-98c34634f08f	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated for Wetv.\nIt connects automatically — no login needed.\nExpires: 01 Aug 2026, 18:32\nReceipt: UH11316L41	talksasa	\N	sent	\N	2026-08-01 14:33:10.377273+00
2ce4793f-a4fd-409a-86ed-53ec96cd72b7	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R10\nPassword: ydxd4c\nExpires: 01 Aug 2026, 18:33\nReceipt: UH11316FJV	talksasa	\N	sent	\N	2026-08-01 14:34:02.04142+00
f20fa933-9970-44a0-ba72-3ec7374bc95f	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R9\nPassword: f85fbx\nExpires: 01 Aug 2026, 18:40\nReceipt: UH11316H29	talksasa	\N	sent	\N	2026-08-01 14:40:06.544231+00
a98bb0ca-f2be-4bbd-91f2-1fca520c79f5	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R11\nPassword: 25847x\nExpires: 01 Aug 2026, 18:45\nReceipt: UH11316P40	talksasa	\N	sent	\N	2026-08-01 14:45:40.934552+00
6e05bf87-d678-4709-b09b-0c373c157043	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R11\nPassword: 4d8fbd\nExpires: 01 Aug 2026, 19:02\nReceipt: UH11316SCX	talksasa	\N	sent	\N	2026-08-01 15:03:00.836237+00
0f4b0b7a-5c17-4153-94b6-8e11f79d26b7	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R12\nPassword: ya9afb\nExpires: 01 Aug 2026, 19:16\nReceipt: UH11316RCU	talksasa	\N	sent	\N	2026-08-01 15:17:00.345174+00
38ccbe3c-70e1-456a-ad65-aa4a4e62048e	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R13\nPassword: 34xd9x\nExpires: 01 Aug 2026, 19:18\nReceipt: UH11316U71	talksasa	\N	sent	\N	2026-08-01 15:19:00.352638+00
9009d305-eb0e-499f-8304-78946c7d2810	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R14\nPassword: x986fy\nExpires: 01 Aug 2026, 19:23\nReceipt: UH11316VU3	talksasa	\N	sent	\N	2026-08-01 15:24:01.001874+00
07a5bf4a-1ff6-4d47-afcf-cf390a371a22	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R15\nPassword: f833cb\nExpires: 01 Aug 2026, 19:25\nReceipt: UH11316T1Z	talksasa	\N	sent	\N	2026-08-01 15:26:01.014422+00
f993f1c9-f64f-49c9-a204-2636212557e5	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 1 Hour activated.\nUsername: R16\nPassword: ef544y\nExpires: 01 Aug 2026, 19:43\nReceipt: UH11316YMW	talksasa	\N	sent	\N	2026-08-01 15:44:01.091565+00
d94a2fb9-87ec-482c-8cf6-b886ccac6693	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 2 Hour activated.\nUsername: R17\nPassword: af9c24\nExpires: 01 Aug 2026, 20:46\nReceipt: UH1131705R	talksasa	\N	sent	\N	2026-08-01 15:47:00.859384+00
253eb652-eabf-4b74-8257-ba7143548c5b	4ed565d4-36d3-4612-90cd-c2fe76cf2314	254740258495	Rumalink: 2 Hour activated.\nUsername: R18\nPassword: cd37f2\nExpires: 01 Aug 2026, 20:58\nReceipt: UH113177QD	talksasa	\N	sent	\N	2026-08-01 15:58:00.967784+00
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
1586	2026-08-01 11:21:25.790691+00	0	0.5	1906	1231	0	20	57	123	11	0	0	ok
1587	2026-08-01 11:22:25.789978+00	0	0	1906	1236	0	20	57	124	11	0	0	ok
1588	2026-08-01 11:23:25.790664+00	0	0	1906	1236	0	20	57	124	11	0	0	ok
1589	2026-08-01 11:24:25.792462+00	0	0	1906	1230	0	20	57	124	17	0	0	ok
1590	2026-08-01 11:25:25.793371+00	0	0	1906	1228	0	20	57	124	17	0	0	ok
1591	2026-08-01 11:26:25.793475+00	0.07	0	1906	1239	0	20	57	124	17	0	0	ok
1592	2026-08-01 11:27:25.792759+00	0.03	0	1906	1226	0	20	57	124	17	0	0	ok
1593	2026-08-01 11:28:25.793831+00	0.04	0	1906	1229	0	20	57	124	15	0	0	ok
1594	2026-08-01 11:29:25.795483+00	0.08	0	1906	1234	0	20	57	123	17	0	0	ok
1595	2026-08-01 11:30:25.795324+00	0.06	0	1906	1230	0	20	57	125	17	0	0	ok
1596	2026-08-01 11:31:25.795198+00	0.02	0	1906	1241	0	20	57	124	14	0	0	ok
1597	2026-08-01 11:32:41.763684+00	0.56	0	1906	1340	0	20	55	98	15	0	0	ok
1598	2026-08-01 11:33:41.747813+00	0.2	0	1906	1368	0	20	55	81	13	0	0	ok
1599	2026-08-01 11:34:41.747695+00	0.07	0	1906	1366	0	20	55	81	13	0	0	ok
1600	2026-08-01 11:35:41.748518+00	0.02	0	1906	1358	0	20	56	93	13	1	0	ok
1601	2026-08-01 11:36:41.750265+00	0.41	0	1906	1354	0	20	56	98	13	1	0	ok
1602	2026-08-01 11:37:41.750918+00	0.41	0	1906	1351	0	20	56	98	13	1	0	ok
1603	2026-08-01 11:38:41.75307+00	0.15	0	1906	1333	0	20	56	104	19	1	0	ok
1604	2026-08-01 11:39:41.75332+00	0.08	0	1906	1345	0	20	56	105	13	1	0	ok
1605	2026-08-01 11:40:41.758146+00	0.25	0	1906	1344	0	20	56	106	13	1	0	ok
1606	2026-08-01 11:41:41.752828+00	0.36	0	1906	1356	0	20	56	106	13	1	0	ok
1607	2026-08-01 11:42:25.483301+00	0.4	0	1906	1375	0	20	56	98	15	1	0	ok
1608	2026-08-01 11:43:25.483251+00	0.26	0	1906	1332	0	20	56	99	20	1	0	ok
1609	2026-08-01 11:44:25.486235+00	0.09	0	1906	1331	0	20	56	102	15	1	0	ok
1610	2026-08-01 11:45:25.483781+00	0.03	0	1906	1337	0	20	56	101	13	1	0	ok
1611	2026-08-01 11:46:25.483193+00	0.17	0	1906	1322	0	20	56	107	20	1	0	ok
1612	2026-08-01 11:47:25.483414+00	0.23	0	1906	1330	0	20	56	104	15	1	0	ok
1613	2026-08-01 11:48:25.483806+00	0.08	0	1906	1332	0	20	56	106	15	1	0	ok
1614	2026-08-01 11:49:25.483408+00	0.14	0	1906	1324	0	20	56	108	17	1	0	ok
1615	2026-08-01 11:50:25.488228+00	0.05	0	1906	1327	0	20	56	110	17	1	0	ok
1616	2026-08-01 11:51:25.482454+00	0.02	0	1906	1324	0	20	56	112	19	1	0	ok
1617	2026-08-01 11:52:25.483378+00	0	0	1906	1313	0	20	56	119	20	1	0	ok
1618	2026-08-01 11:53:25.485044+00	0.23	0	1906	1314	0	20	56	120	19	1	0	ok
1619	2026-08-01 11:54:25.483803+00	0.38	0	1906	1323	0	20	56	120	18	1	0	ok
1620	2026-08-01 11:55:25.503322+00	0.48	0	1906	1317	0	20	56	120	17	1	0	ok
1621	2026-08-01 11:56:25.486539+00	0.4	0	1906	1318	0	20	56	121	20	1	0	ok
1622	2026-08-01 11:57:25.485999+00	0.26	0	1906	1307	0	20	56	120	20	1	0	ok
1623	2026-08-01 11:58:25.488235+00	0.09	0	1906	1314	0	20	57	121	17	1	0	ok
1624	2026-08-01 11:59:25.485855+00	0.03	0	1906	1318	0	20	57	121	17	1	0	ok
1625	2026-08-01 12:00:25.485985+00	0.3	0	1906	1310	0	20	57	122	18	1	0	ok
1626	2026-08-01 12:01:25.487848+00	0.39	0	1906	1309	0	20	57	122	17	1	0	ok
1627	2026-08-01 12:02:25.488236+00	0.2	0	1906	1306	0	20	57	124	20	1	0	ok
1628	2026-08-01 12:03:25.491745+00	0.19	0	1906	1312	0	20	57	123	18	1	0	ok
1629	2026-08-01 12:04:25.489183+00	0.15	0	1906	1313	0	20	57	126	19	1	0	ok
1630	2026-08-01 12:05:25.48987+00	0.05	0	1906	1313	0	20	57	123	17	1	0	ok
1631	2026-08-01 12:06:25.490691+00	0.19	0	1906	1325	0	20	57	119	17	1	0	ok
1632	2026-08-01 12:07:25.493861+00	0.12	0	1906	1316	0	20	57	121	17	1	0	ok
1633	2026-08-01 12:08:25.493414+00	0.16	0	1906	1310	0	20	57	123	16	1	0	ok
1634	2026-08-01 12:09:25.495475+00	0.11	0.5	1906	1311	0	20	57	123	19	1	0	ok
1635	2026-08-01 12:10:25.494781+00	0.33	0	1906	1311	0	20	57	124	19	1	0	ok
1636	2026-08-01 12:11:25.501766+00	0.17	0	1906	1317	0	20	57	125	17	1	0	ok
1637	2026-08-01 12:12:25.496224+00	0.35	0	1906	1322	0	20	57	124	17	1	0	ok
1638	2026-08-01 12:13:25.496403+00	0.18	0	1906	1315	0	20	57	126	18	1	0	ok
1639	2026-08-01 12:14:25.497129+00	0.12	0	1906	1313	0	20	57	125	20	1	0	ok
1640	2026-08-01 12:15:25.499547+00	0.16	0	1906	1312	0	20	57	124	18	1	0	ok
1641	2026-08-01 12:16:25.500594+00	0.11	0.5	1906	1302	0	20	57	125	19	1	0	ok
1642	2026-08-01 12:17:25.498736+00	0.1	0	1906	1304	0	20	57	125	19	1	0	ok
1643	2026-08-01 12:18:25.497588+00	0.26	0	1906	1306	0	20	57	125	18	1	0	ok
1644	2026-08-01 12:19:25.498558+00	0.21	0.5	1906	1288	0	20	57	125	21	1	0	ok
1645	2026-08-01 12:20:25.500073+00	0.13	0	1906	1307	0	20	57	125	20	1	0	ok
1646	2026-08-01 12:21:25.497671+00	0.1	0	1906	1307	0	20	57	125	18	1	0	ok
1647	2026-08-01 12:22:25.498466+00	0.04	0	1906	1308	0	20	57	126	18	1	0	ok
1648	2026-08-01 12:23:25.500149+00	0.16	0	1906	1313	0	20	57	125	19	1	0	ok
1649	2026-08-01 12:24:25.501401+00	0.11	0	1906	1299	0	20	57	125	20	1	0	ok
1650	2026-08-01 12:25:25.499921+00	0.1	0.5	1906	1314	0	20	57	125	18	1	0	ok
1651	2026-08-01 12:26:25.503198+00	0.09	0	1906	1303	0	20	57	126	17	1	0	ok
1652	2026-08-01 12:27:25.502598+00	0.09	0	1906	1312	0	20	57	125	17	1	0	ok
1653	2026-08-01 12:28:25.502049+00	0.09	0	1906	1312	0	20	57	125	18	1	0	ok
1654	2026-08-01 12:29:25.502185+00	0.09	0	1906	1312	0	20	57	126	20	1	0	ok
1655	2026-08-01 12:30:25.502739+00	0.09	0	1906	1315	0	20	57	126	13	1	0	ok
1656	2026-08-01 12:31:25.504233+00	0.09	0	1906	1325	0	20	57	125	12	1	0	ok
1657	2026-08-01 12:32:25.505141+00	0.09	0	1906	1311	0	20	57	126	18	1	0	ok
1658	2026-08-01 12:33:25.505854+00	0.14	0	1906	1309	0	20	57	126	19	1	0	ok
1659	2026-08-01 12:34:25.505199+00	0.23	0	1906	1300	0	20	57	126	18	1	0	ok
1660	2026-08-01 12:35:25.507432+00	0.29	0	1906	1316	0	20	57	127	17	1	0	ok
1661	2026-08-01 12:36:25.507484+00	0.16	0	1906	1299	0	20	57	126	17	1	0	ok
1662	2026-08-01 12:37:25.507867+00	0.12	0	1906	1297	0	20	57	127	19	1	0	ok
1663	2026-08-01 12:38:25.508217+00	0.16	0	1906	1287	0	20	57	126	18	1	0	ok
1664	2026-08-01 12:39:25.507108+00	0.11	0	1906	1295	0	20	57	126	20	1	0	ok
1665	2026-08-01 12:40:25.509744+00	0.1	0	1906	1291	0	20	57	127	21	1	0	ok
1666	2026-08-01 12:41:25.509064+00	0.15	0	1906	1298	0	20	57	127	17	1	0	ok
1667	2026-08-01 12:42:25.509911+00	0.11	0	1906	1282	0	20	57	127	20	1	0	ok
1668	2026-08-01 12:43:25.509962+00	0.1	0	1906	1291	0	20	57	127	17	1	0	ok
1669	2026-08-01 12:44:25.510334+00	0.09	0	1906	1291	0	20	57	127	17	1	0	ok
1670	2026-08-01 12:45:25.509971+00	0.09	0	1906	1301	0	20	57	127	16	1	0	ok
1671	2026-08-01 12:46:25.508822+00	0.09	0	1906	1299	0	20	57	127	15	1	0	ok
1672	2026-08-01 12:47:25.520229+00	0.09	0	1906	1296	0	20	57	127	18	1	0	ok
1673	2026-08-01 12:48:25.510123+00	0.03	0	1906	1291	0	20	57	127	19	1	0	ok
1674	2026-08-01 12:49:25.509757+00	0.07	0	1906	1288	0	20	57	127	19	1	0	ok
1675	2026-08-01 12:50:25.50859+00	0.2	0	1906	1289	0	20	57	127	19	1	0	ok
1676	2026-08-01 12:51:25.509313+00	0.13	0	1906	1294	0	20	57	128	16	1	0	ok
1677	2026-08-01 12:52:25.509418+00	0.1	0	1906	1301	0	20	57	127	15	1	0	ok
1678	2026-08-01 12:53:25.508816+00	0.15	0	1906	1295	0	20	57	127	13	1	0	ok
1679	2026-08-01 12:54:25.510656+00	0.35	0	1906	1300	0	20	57	128	14	1	0	ok
1680	2026-08-01 12:55:25.511296+00	0.18	0	1906	1296	0	20	57	127	11	1	0	ok
1681	2026-08-01 12:56:25.508882+00	0.12	0.5	1906	1302	0	20	57	127	13	1	0	ok
1682	2026-08-01 12:56:27.257837+00	0.12	0	1906	1354	0	20	57	98	12	1	0	ok
1683	2026-08-01 12:57:27.25699+00	0.27	0	1906	1320	0	20	57	99	13	1	0	ok
1684	2026-08-01 12:58:27.256769+00	0.16	0	1906	1312	0	20	57	103	13	1	0	ok
1685	2026-08-01 12:59:27.256303+00	0.11	0	1906	1320	0	20	57	104	13	1	0	ok
1686	2026-08-01 13:00:27.258787+00	0.09	0	1906	1321	0	20	57	106	12	1	0	ok
1687	2026-08-01 13:01:27.257447+00	0.09	0.5	1906	1319	0	20	57	107	11	1	0	ok
1688	2026-08-01 13:02:27.259083+00	0.09	0	1906	1313	0	20	57	108	13	1	0	ok
1689	2026-08-01 13:03:27.258761+00	0.09	0	1906	1314	0	20	57	108	13	1	0	ok
1690	2026-08-01 13:04:27.259238+00	0.09	0	1906	1290	0	20	57	113	11	1	0	ok
1691	2026-08-01 13:05:27.259772+00	0.03	0	1906	1296	0	20	57	121	16	1	0	ok
1692	2026-08-01 13:06:27.261722+00	0.07	0	1906	1307	0	20	57	115	15	1	0	ok
1693	2026-08-01 13:07:27.261069+00	0.08	0	1906	1316	0	20	57	118	12	1	0	ok
1694	2026-08-01 13:08:27.26005+00	0.08	0	1906	1304	0	20	57	120	17	1	0	ok
1695	2026-08-01 13:09:27.260456+00	0.09	0	1906	1301	0	20	57	122	16	1	0	ok
1696	2026-08-01 13:10:27.260781+00	0.09	0	1906	1302	0	20	57	122	15	1	0	ok
1697	2026-08-01 13:11:27.262731+00	0.24	0	1906	1265	0	20	57	123	18	1	0	ok
1698	2026-08-01 13:12:27.264219+00	0.18	0	1906	1258	0	20	57	122	17	1	0	ok
1699	2026-08-01 13:13:27.263048+00	0.18	0	1906	1264	0	20	57	123	17	1	0	ok
1700	2026-08-01 13:14:27.262428+00	0.12	0	1906	1255	0	20	57	123	17	1	0	ok
1701	2026-08-01 13:15:27.262692+00	0.1	0	1906	1262	0	20	57	123	18	1	0	ok
1702	2026-08-01 13:16:27.262026+00	0.09	0	1906	1261	0	20	57	124	19	1	0	ok
1703	2026-08-01 13:17:27.265035+00	0.09	0.5	1906	1257	0	20	57	123	18	1	0	ok
1704	2026-08-01 13:18:27.2645+00	0.09	0	1906	1262	0	20	57	124	16	1	0	ok
1705	2026-08-01 13:19:27.265641+00	0.03	0	1906	1261	0	20	57	123	17	1	0	ok
1706	2026-08-01 13:20:27.265959+00	0.07	0	1906	1263	0	20	57	123	18	1	0	ok
1707	2026-08-01 13:21:27.273293+00	0.02	0	1906	1256	0	20	57	124	17	1	0	ok
1708	2026-08-01 13:22:27.268254+00	0.01	0	1906	1258	0	20	57	124	16	1	0	ok
1709	2026-08-01 13:23:27.267698+00	0	0	1906	1256	0	20	57	124	15	1	0	ok
1710	2026-08-01 13:24:27.270965+00	0	0.5	1906	1263	0	20	57	124	14	1	0	ok
1711	2026-08-01 13:25:27.270795+00	0.09	0	1906	1260	0	20	57	124	16	1	0	ok
1712	2026-08-01 13:26:27.270514+00	0.03	0	1906	1258	0	20	57	124	16	1	0	ok
1713	2026-08-01 13:27:27.270467+00	0.1	0	1906	1258	0	20	57	124	15	1	0	ok
1714	2026-08-01 13:28:27.271098+00	0.15	0	1906	1257	0	20	57	124	16	1	0	ok
1715	2026-08-01 13:29:27.271546+00	0.23	0	1906	1255	0	20	57	124	15	1	0	ok
1716	2026-08-01 13:30:27.272996+00	0.14	0	1906	1246	0	20	57	125	16	1	0	ok
1717	2026-08-01 13:31:27.272961+00	0.11	0	1906	1250	0	20	57	125	17	1	0	ok
1718	2026-08-01 13:32:27.271745+00	0.1	0	1906	1246	0	20	57	124	17	1	0	ok
1719	2026-08-01 13:33:27.272663+00	0.15	0	1906	1251	0	20	57	125	18	1	0	ok
1720	2026-08-01 13:34:27.272926+00	0.11	0	1906	1257	0	20	57	124	17	1	0	ok
1721	2026-08-01 13:35:27.274093+00	0.21	0	1906	1252	0	20	57	125	18	1	0	ok
1722	2026-08-01 13:36:27.273924+00	0.13	0	1906	1255	0	20	57	124	19	1	0	ok
1723	2026-08-01 13:37:27.274718+00	0.1	0	1906	1253	0	20	57	124	17	1	0	ok
1724	2026-08-01 13:38:27.275041+00	0.21	0	1906	1251	0	20	57	125	19	1	0	ok
1725	2026-08-01 13:38:52.431012+00	0.14	0	1906	1321	0	20	57	98	12	1	0	ok
1726	2026-08-01 13:39:52.429374+00	0.05	0	1906	1293	0	20	57	88	10	1	0	ok
1727	2026-08-01 13:40:52.42876+00	0.05	0	1906	1292	0	20	57	93	10	1	0	ok
1728	2026-08-01 13:41:52.426983+00	0.02	0	1906	1296	0	20	57	96	10	1	0	ok
1729	2026-08-01 13:41:58.231531+00	0.02	0	1906	1321	0	20	57	98	12	1	0	ok
1730	2026-08-01 13:42:58.230715+00	0.04	0	1906	1299	0	20	57	92	10	1	0	ok
1731	2026-08-01 13:43:58.233816+00	0.01	0	1906	1295	0	20	57	97	13	1	0	ok
1732	2026-08-01 13:44:18.273035+00	0.01	0	1906	1316	0	20	57	99	12	1	0	ok
1733	2026-08-01 13:45:18.273236+00	0.07	0	1906	1278	0	20	57	92	18	1	0	ok
1734	2026-08-01 13:46:18.272947+00	0.1	0	1906	1283	0	20	57	93	15	1	0	ok
1735	2026-08-01 13:47:18.270762+00	0.03	0	1906	1286	0	20	57	97	14	1	0	ok
1736	2026-08-01 13:48:18.276313+00	0.08	0	1906	1277	0	20	57	100	15	1	0	ok
1737	2026-08-01 13:49:18.277506+00	0.03	0	1906	1282	0	20	57	97	15	1	0	ok
1738	2026-08-01 13:50:18.275886+00	0.08	0	1906	1280	0	20	57	99	18	1	0	ok
1739	2026-08-01 13:51:18.278217+00	0.03	0	1906	1265	0	20	57	102	18	1	0	ok
1740	2026-08-01 13:51:31.127349+00	0.02	0	1906	1307	0	20	57	99	12	1	0	ok
1741	2026-08-01 13:52:31.128503+00	0.01	0	1906	1284	0	20	57	94	11	1	0	ok
1742	2026-08-01 13:53:31.129246+00	0	0	1906	1277	0	20	57	97	12	1	0	ok
1743	2026-08-01 13:54:31.131251+00	0.05	0	1906	1260	0	20	57	110	16	1	0	ok
1744	2026-08-01 13:55:31.130431+00	0.02	0	1906	1274	0	20	57	105	13	1	0	ok
1745	2026-08-01 13:56:31.129001+00	0	0	1906	1275	0	20	57	109	9	1	0	ok
1746	2026-08-01 13:57:31.129936+00	0	0	1906	1269	0	20	57	111	10	1	0	ok
1747	2026-08-01 13:58:31.130233+00	0	0	1906	1260	0	20	57	112	11	1	0	ok
1748	2026-08-01 13:59:31.130375+00	0.05	0	1906	1263	0	20	57	112	11	1	0	ok
1749	2026-08-01 14:00:31.133132+00	0.12	0.5	1906	1268	0	20	57	113	10	1	0	ok
1750	2026-08-01 14:01:31.135634+00	0.04	0	1906	1268	0	20	57	113	11	1	0	ok
1751	2026-08-01 14:02:31.135396+00	0.01	0.5	1906	1266	0	20	57	114	11	1	0	ok
1752	2026-08-01 14:03:32.509289+00	0	0	1906	1305	0	20	57	99	12	1	0	ok
1753	2026-08-01 14:04:32.510974+00	0.05	0	1906	1294	0	20	57	92	11	1	0	ok
1754	2026-08-01 14:05:32.508147+00	0.02	0	1906	1281	0	20	57	98	11	1	0	ok
1755	2026-08-01 14:06:32.507062+00	0.1	0	1906	1274	0	20	57	104	10	1	0	ok
1756	2026-08-01 14:07:32.508193+00	0.04	0	1906	1272	0	20	57	99	11	1	0	ok
1757	2026-08-01 14:08:32.508236+00	0.23	0	1906	1265	0	20	57	107	19	1	0	ok
1758	2026-08-01 14:09:32.508784+00	0.08	0	1906	1259	0	20	57	114	14	1	0	ok
1759	2026-08-01 14:10:32.510684+00	0.08	0	1906	1260	0	20	57	114	12	1	0	ok
1760	2026-08-01 14:11:32.515026+00	0.03	0	1906	1266	0	20	57	116	10	1	0	ok
1761	2026-08-01 14:12:32.509939+00	0.06	0	1906	1273	0	20	57	115	10	1	0	ok
1762	2026-08-01 14:13:32.509245+00	0.02	0	1906	1268	0	20	57	115	11	1	0	ok
1763	2026-08-01 14:14:32.509733+00	0.22	0	1906	1275	0	20	57	116	11	1	0	ok
1764	2026-08-01 14:15:32.50866+00	0.08	0	1906	1259	0	20	57	115	10	1	0	ok
1765	2026-08-01 14:16:32.513161+00	0.03	0	1906	1255	0	20	57	115	10	1	0	ok
1766	2026-08-01 14:17:32.510004+00	0.01	0	1906	1264	0	20	57	116	11	1	0	ok
1767	2026-08-01 14:17:47.202182+00	0.01	0	1906	1308	0	20	57	99	12	1	0	ok
1768	2026-08-01 14:18:47.201949+00	0.12	0	1906	1287	0	20	57	91	11	1	0	ok
1769	2026-08-01 14:19:47.202818+00	0.04	0	1906	1282	0	20	57	94	12	1	0	ok
1770	2026-08-01 14:20:47.203729+00	0.01	0	1906	1275	0	20	57	100	11	1	0	ok
1771	2026-08-01 14:21:47.203802+00	0	0	1906	1264	0	20	57	106	12	1	0	ok
1772	2026-08-01 14:22:47.203802+00	0.04	0	1906	1272	0	20	57	111	10	1	0	ok
1773	2026-08-01 14:23:47.204099+00	0.01	0	1906	1276	0	20	57	112	12	1	0	ok
1774	2026-08-01 14:24:47.204382+00	0	0	1906	1274	0	20	57	112	10	1	0	ok
1775	2026-08-01 14:25:47.204711+00	0	0	1906	1263	0	20	57	113	10	1	0	ok
1776	2026-08-01 14:26:47.203044+00	0	0	1906	1275	0	20	57	114	9	1	0	ok
1777	2026-08-01 14:27:38.187151+00	0	0	1906	1310	0	20	57	98	12	1	0	ok
1778	2026-08-01 14:27:49.928616+00	0	0	1906	1291	0	20	57	98	12	1	0	ok
1779	2026-08-01 14:28:49.924752+00	0	0	1906	1282	0	20	57	92	11	1	0	ok
1780	2026-08-01 14:29:49.925244+00	0	0	1906	1265	0	20	57	98	17	1	0	ok
1781	2026-08-01 14:30:49.927499+00	0.04	0	1906	1268	0	20	57	103	16	1	0	ok
1782	2026-08-01 14:31:49.929705+00	0.01	0	1906	1268	0	20	57	107	13	1	0	ok
1783	2026-08-01 14:32:49.930501+00	0	0	1906	1262	0	20	57	111	12	1	0	ok
1784	2026-08-01 14:33:49.930495+00	0	0	1906	1269	0	20	57	115	13	1	0	ok
1785	2026-08-01 14:34:49.933122+00	0.07	0	1906	1263	0	20	57	114	10	1	0	ok
1786	2026-08-01 14:35:49.930526+00	0.02	0	1906	1272	0	20	57	114	10	1	0	ok
1787	2026-08-01 14:36:49.932219+00	0.01	0	1906	1257	0	20	57	116	12	1	0	ok
1788	2026-08-01 14:37:49.931349+00	0.15	0	1906	1258	0	20	57	116	10	1	0	ok
1789	2026-08-01 14:38:43.06074+00	0.06	0	1906	1295	0	20	57	98	13	1	0	ok
1790	2026-08-01 14:39:43.062002+00	0.02	0	1906	1282	0	20	57	94	12	1	0	ok
1791	2026-08-01 14:40:43.062047+00	0.01	0	1906	1269	0	20	57	106	16	1	0	ok
1792	2026-08-01 14:41:43.062239+00	0	0	1906	1271	0	20	57	108	12	1	0	ok
1793	2026-08-01 14:42:43.06443+00	0	0	1906	1269	0	20	57	110	10	1	0	ok
1794	2026-08-01 14:43:00.230183+00	0	1	1906	1302	0	20	57	99	11	1	0	ok
1795	2026-08-01 14:44:00.231237+00	0	1	1906	1280	0	20	57	96	10	1	0	ok
1796	2026-08-01 14:45:00.228949+00	0	3.92	1906	1273	0	20	57	102	18	1	0	ok
1797	2026-08-01 14:46:00.222904+00	0	1.49	1906	1262	0	20	57	112	11	1	0	ok
1798	2026-08-01 14:47:00.225981+00	0	0	1906	1275	0	20	57	106	12	1	0	ok
1799	2026-08-01 14:48:00.225545+00	0	0	1906	1273	0	20	57	110	10	1	0	ok
1800	2026-08-01 14:55:46.382636+00	1.86	0.5	1906	1273	0	20	57	98	12	1	0	ok
1801	2026-08-01 14:56:46.385619+00	0.68	0	1906	1271	0	20	57	98	11	1	0	ok
1802	2026-08-01 14:57:46.384114+00	0.25	0	1906	1270	0	20	57	103	11	1	0	ok
1803	2026-08-01 14:58:46.384686+00	0.09	0	1906	1261	0	20	57	99	11	1	0	ok
1804	2026-08-01 14:59:46.383802+00	0.03	0	1906	1258	0	20	57	102	12	1	0	ok
1805	2026-08-01 15:00:46.38465+00	0.05	0	1906	1261	0	20	57	106	11	1	0	ok
1806	2026-08-01 15:01:46.385251+00	0.02	0	1906	1249	0	20	57	108	10	1	0	ok
1807	2026-08-01 15:02:46.38507+00	0	0	1906	1258	0	20	57	109	12	1	0	ok
1808	2026-08-01 15:03:46.385486+00	0	0	1906	1253	0	20	57	117	13	1	0	ok
1809	2026-08-01 15:04:46.386035+00	0	0	1906	1247	0	20	57	116	9	1	0	ok
1810	2026-08-01 15:05:46.386641+00	0	0	1906	1260	0	20	57	117	10	1	0	ok
1811	2026-08-01 15:06:46.387273+00	0	0	1906	1262	0	20	57	118	10	1	0	ok
1812	2026-08-01 15:07:46.394396+00	0	0	1906	1243	0	20	57	117	11	1	0	ok
1813	2026-08-01 15:08:46.389917+00	0	0	1906	1246	0	20	57	117	11	1	0	ok
1814	2026-08-01 15:09:46.388852+00	0	0	1906	1249	0	20	57	118	11	1	0	ok
1815	2026-08-01 15:10:46.387307+00	0.04	0	1906	1264	0	20	57	117	10	1	0	ok
1816	2026-08-01 15:11:46.38863+00	0.01	0	1906	1247	0	20	57	118	11	1	0	ok
1817	2026-08-01 15:12:46.387627+00	0	0	1906	1253	0	20	57	118	10	1	0	ok
1818	2026-08-01 15:13:46.389347+00	0	0	1906	1257	0	20	57	118	12	1	0	ok
1819	2026-08-01 15:14:46.391832+00	0	0	1906	1259	0	20	57	117	11	1	0	ok
1820	2026-08-01 15:15:46.389176+00	0	0	1906	1256	0	20	57	119	12	1	0	ok
1821	2026-08-01 15:16:46.389087+00	0	0	1906	1242	0	20	57	118	12	1	0	ok
1822	2026-08-01 15:17:46.389075+00	0	0	1906	1245	0	20	57	119	12	1	0	ok
1823	2026-08-01 15:18:46.390425+00	0	0	1906	1256	0	20	57	119	12	1	0	ok
1824	2026-08-01 15:19:46.390529+00	0	0	1906	1262	0	20	57	114	12	1	0	ok
1825	2026-08-01 15:20:46.389437+00	0	0	1906	1257	0	20	57	116	9	1	0	ok
1826	2026-08-01 15:21:03.961252+00	0	8.96	1906	1259	0	20	57	100	11	1	0	critical
1827	2026-08-01 15:22:02.84191+00	0.17	21.89	1906	1265	0	20	57	100	16	1	0	critical
1828	2026-08-01 15:23:02.877514+00	0.06	33	1906	1264	0	20	57	103	13	1	0	critical
1829	2026-08-01 15:24:02.899068+00	0.02	40.49	1906	1241	0	20	57	108	17	1	0	critical
1830	2026-08-01 15:25:02.925104+00	0.01	44.22	1906	1256	0	20	57	111	18	1	0	critical
1831	2026-08-01 15:26:02.891878+00	0	20.67	1906	1233	0	20	57	116	17	1	0	critical
1832	2026-08-01 15:27:02.902693+00	0	7.77	1906	1237	0	20	57	115	17	1	0	critical
1833	2026-08-01 15:28:02.902042+00	0	21.5	1906	1241	0	20	57	116	16	1	0	critical
1834	2026-08-01 15:29:02.912179+00	0	20.3	1906	1260	0	20	57	116	16	1	0	critical
1835	2026-08-01 15:30:03.043244+00	0.06	72.28	1906	1266	0	20	57	115	17	1	0	critical
1836	2026-08-01 15:31:02.979413+00	0.02	34.17	1906	1254	0	20	57	116	17	1	0	critical
1837	2026-08-01 15:32:02.977762+00	0.22	13.73	1906	1239	0	20	57	116	17	1	0	critical
1838	2026-08-01 15:33:02.98062+00	0.32	13.11	1906	1243	0	20	57	116	16	1	0	critical
1839	2026-08-01 15:34:02.985192+00	0.85	29.61	1906	1239	0	20	57	117	17	1	0	critical
1840	2026-08-01 15:34:40.331482+00	0.47	0	1906	1301	0	20	57	99	13	1	0	ok
1841	2026-08-01 15:35:39.28436+00	0.2	0	1906	1266	0	20	57	97	12	1	0	ok
1842	2026-08-01 15:36:39.288355+00	0.07	0	1906	1277	0	20	57	100	13	1	0	ok
1843	2026-08-01 15:37:39.286304+00	0.02	0	1906	1272	0	20	57	102	11	1	0	ok
1844	2026-08-01 15:38:39.287458+00	0.01	0	1906	1263	0	20	57	105	10	1	0	ok
1845	2026-08-01 15:39:39.289604+00	0	0	1906	1268	0	20	57	98	10	1	0	ok
1846	2026-08-01 15:40:39.288741+00	0	0	1906	1261	0	20	57	100	12	1	0	ok
1847	2026-08-01 15:41:39.290657+00	0	0	1906	1270	0	20	57	103	12	1	0	ok
1848	2026-08-01 15:42:39.294963+00	0	0	1906	1265	0	20	57	105	11	1	0	ok
1849	2026-08-01 15:43:39.293105+00	0	0	1906	1262	0	20	57	106	10	1	0	ok
1850	2026-08-01 15:44:39.292652+00	0	0	1906	1254	0	20	57	113	12	1	0	ok
1851	2026-08-01 15:45:39.291728+00	0	0	1906	1247	0	20	57	113	17	1	0	ok
1852	2026-08-01 15:46:39.293593+00	0	0	1906	1259	0	20	57	114	13	1	0	ok
1853	2026-08-01 15:47:39.291518+00	0	0	1906	1262	0	20	57	114	11	1	0	ok
1854	2026-08-01 15:48:39.291815+00	0	0	1906	1261	0	20	57	115	12	1	0	ok
1855	2026-08-01 15:49:39.292097+00	0	0	1906	1266	0	20	57	114	13	1	0	ok
1856	2026-08-01 15:50:39.292793+00	0	0	1906	1257	0	20	57	116	14	1	0	ok
1857	2026-08-01 15:51:39.292098+00	0	0	1906	1267	0	20	57	116	10	1	0	ok
1858	2026-08-01 15:52:39.293588+00	0.06	0	1906	1254	0	20	57	117	12	1	0	ok
1859	2026-08-01 15:52:44.655504+00	0.06	0.5	1906	1302	0	20	57	98	12	1	0	ok
1860	2026-08-01 15:53:44.655001+00	0.08	0	1906	1295	0	20	57	92	10	1	0	ok
1861	2026-08-01 15:54:44.654848+00	0.03	0	1906	1280	0	20	57	98	11	1	0	ok
1862	2026-08-01 15:55:44.653787+00	0.01	0	1906	1281	0	20	57	100	10	1	0	ok
1863	2026-08-01 15:56:25.516598+00	0	0.5	1906	1290	0	20	57	99	13	1	0	ok
1864	2026-08-01 15:57:25.514793+00	0.07	0	1906	1271	0	20	57	92	18	1	0	ok
1865	2026-08-01 15:58:25.514065+00	0.02	0	1906	1250	0	20	57	109	19	1	0	ok
1866	2026-08-01 15:59:25.51527+00	0.01	0	1906	1246	0	20	57	112	20	1	0	ok
1867	2026-08-01 16:00:25.515711+00	0.17	0	1906	1256	0	20	57	108	18	1	0	ok
1868	2026-08-01 16:01:25.515156+00	0.06	0.5	1906	1252	0	20	57	111	16	1	0	ok
\.


--
-- Data for Name: system_health_alerts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_health_alerts (id, metric, severity, value, threshold, message, opened_at, closed_at) FROM stdin;
1	routers_down	warning	1	0	Router(s) unreachable: 1 (threshold > 0). Affected ISPs cannot authenticate customers.	2026-07-31 09:51:37.839908+00	2026-07-31 09:59:37.841971+00
2	cpu_steal	critical	8.96	5	CPU throttled by AWS: 8.96 % (threshold > 5). Burst credits are exhausted. Only a plan with more vCPUs resolves this.	2026-08-01 15:21:02.83619+00	2026-08-01 15:34:39.286647+00
\.


--
-- Data for Name: usage_daily; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_daily (isp_id, device_id, username, usage_day, bytes_in, bytes_out, updated_at) FROM stdin;
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R11@4ed565d4	2026-08-01	1660552	18898420	2026-08-01 15:16:01.461482+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R12@4ed565d4	2026-08-01	101087	81441	2026-08-01 15:18:02.279439+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R13@4ed565d4	2026-08-01	178542	159372	2026-08-01 15:23:02.30237+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R14@4ed565d4	2026-08-01	54856	69012	2026-08-01 15:25:02.617946+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R15@4ed565d4	2026-08-01	213982	155826	2026-08-01 15:36:01.17338+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R16@4ed565d4	2026-08-01	211298	293306	2026-08-01 15:46:01.398235+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R17@4ed565d4	2026-08-01	291117	689090	2026-08-01 15:56:02.445248+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	benard	2026-08-01	28661880	112774502	2026-08-01 15:59:02.216188+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R18@4ed565d4	2026-08-01	238164	140313	2026-08-01 16:01:02.12506+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R1@4ed565d4	2026-08-01	1563561	1934856	2026-08-01 14:30:03.162399+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R10@4ed565d4	2026-08-01	394423	595826	2026-08-01 14:40:02.617664+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R9@4ed565d4	2026-08-01	699187	4874480	2026-08-01 14:45:02.468643+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	66:87:6A:49:95:DA	2026-08-01	1557057	17223680	2026-08-01 12:42:02.070713+00
4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	R2@4ed565d4	2026-08-01	929141	1289570	2026-08-01 12:49:02.351112+00
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
8a6609cef8c88e834b998d5c5d3a74dc	8000003f	R17@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	291117	689090	2026-08-01 15:58:02.158336+00
3b508800c6d25f424f40545c6606ea92	80000031	R11@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	1328464	18488351	2026-08-01 15:04:01.794251+00
b7e24f01094ccdaa1ffcbb145d5d3489	81000026	benard	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	20248061	88464350	2026-08-01 16:02:01.27924+00
14d757e7b4b3ab7845f647d09a8ec331	80000044	R18@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	238164	140313	2026-08-01 16:02:01.27924+00
bff54a18c38359bc7f3b2feda8be3656	80000020	R2@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	929141	1289570	2026-08-01 12:54:02.472722+00
713f0438671eb7d154d40a5229a90381	8000002f	R10@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	394423	595826	2026-08-01 14:42:02.47792+00
756b5117e54d862187a649562336c82b	80000019	66:87:6A:49:95:DA	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	60	260	2026-08-01 11:51:01.730246+00
5cb2b75fd1594370eeedafc208242777	8000001b	R1@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	152304	150458	2026-08-01 11:52:01.377185+00
9f701dcb867e62d346006d95b45c709b	8000003b	R15@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	213982	155826	2026-08-01 15:38:01.238323+00
8de2618ddfc4e433404fb12f72ed1154	8000002b	R1@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	451837	893272	2026-08-01 14:22:01.61672+00
f700064cd0d98145a7412cd9bb0cb881	80000030	R9@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	699187	4874480	2026-08-01 14:47:01.494273+00
adda2de958c3db257310e6e59c59eedf	81000023	benard	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	8188835	24020786	2026-08-01 11:58:01.682469+00
080c667d29dd4b3d5a9f6eb7cd4e9cb5	81000024	benard	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	122331	56459	2026-08-01 11:58:01.682469+00
af9ad27facaceed3c0390dc93cf00158	81000025	benard	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	224984	289366	2026-08-01 12:01:02.357337+00
aa7b9410ac877ba005a0f7dcb3753d8f	80000034	R11@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	332088	410069	2026-08-01 15:18:02.279439+00
881e06c0c474ecea6eaec805f4f01a21	8000003e	R16@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	211298	293306	2026-08-01 15:48:02.510358+00
6739db4c818a7f8994d6bc01012eb141	80000021	66:87:6A:49:95:DA	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	1556997	17223420	2026-08-01 12:44:02.018724+00
411942c680d7968696f60976d16e33cb	80000035	R12@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	101087	81441	2026-08-01 15:20:02.143589+00
02a8d90c86a36e1121d3246d484adf51	8000002c	R1@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	322663	352961	2026-08-01 14:32:02.272242+00
7587ca69b33dde7becdc40ece0fe13af	8000002d	R9@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	86926	71455	2026-08-01 14:33:02.246388+00
e112bd7edc5227ec1a5e1f60e185565d	80000028	R1@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	636757	538165	2026-08-01 14:09:02.176509+00
a9edc377682204ee099667e9cea8067e	8000002e	R9@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	74504	165648	2026-08-01 14:34:02.40053+00
58f44fd55b8c96daeed399f779eed388	80000037	R13@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	178542	159372	2026-08-01 15:25:02.617946+00
13833e337aa22e85527d93643071b0b8	80000039	R14@4ed565d4	4ed565d4-36d3-4612-90cd-c2fe76cf2314	da8f681c-2936-449a-8c5a-87c5bf26fcdd	54856	69012	2026-08-01 15:27:01.837247+00
\.


--
-- Data for Name: verification_codes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_codes (id, isp_id, channel, target, code_hash, expires_at, attempts, consumed_at, ip, created_at, selector) FROM stdin;
1	4ed565d4-36d3-4612-90cd-c2fe76cf2314	email	rumalinkenterprise@gmail.com	84ce21b1e8d22d32.002ac3f59723df5458e3974b7b23181ed870198458bda3e4d859a293485b3775	2026-08-02 11:22:54.212422+00	0	2026-08-01 11:23:07.521628+00	102.205.237.69	2026-08-01 11:22:54.212422+00	462ee39dc8b6
2	4ed565d4-36d3-4612-90cd-c2fe76cf2314	phone	254704994652	dc4998a21064d4e8.bc11500629e4bfc8a6f546077107ff366ca35600efaacf3b05f67468a800ae59	2026-08-01 11:33:12.607134+00	0	2026-08-01 11:24:03.934156+00	102.205.237.69	2026-08-01 11:23:12.607134+00	\N
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

SELECT pg_catalog.setval('public.radacct_radacctid_seq', 26, true);


--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.radcheck_delete_audit_id_seq', 240, true);


--
-- Name: radcheck_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radcheck_id_seq', 71, true);


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

SELECT pg_catalog.setval('public.radpostauth_id_seq', 48, true);


--
-- Name: radreply_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radreply_id_seq', 6070, true);


--
-- Name: system_health_alerts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_health_alerts_id_seq', 2, true);


--
-- Name: system_health_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_health_id_seq', 1868, true);


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

\unrestrict HOzOg6QpcSaLoZ46w2Bu50Tr1SDcxdSL3Xx2YN1DJeGdVAffcbwxFwaLCgaqRSE

