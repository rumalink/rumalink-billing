--
-- PostgreSQL database dump
--

\restrict 27TVqGAMR3kp6Z2toTc4coJdWeGJY7vE0ROsq8NSHSYWN8BF59mAZDGke1fz3E0

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
    provider character varying(32)
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
e0556dcb-b203-4e85-b0c4-bd657bddcf62	RumaLink Admin	admin@rumalink.co.ke	$2a$12$lW4s6qSv6dP4ZBV4CMkUq.hwqqCiaphkhsZ6qELmJdG7MwF1axeje	superadmin	t	2026-07-31 18:20:37.186145+00	2026-05-24 08:18:35.982073+00	2026-05-24 08:18:35.982073+00
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
f7fcbae9-2a76-476e-94c9-c93060e321a0	98d7ba07-2dd2-42d0-819e-e438ea390565	e5826f3e-20c7-486b-a7c1-bb9f5fe068b6	0.15	0.0300	\N	\N	f	\N	2026-07-31 11:12:00.568144+00
5667a2c8-6806-4521-a7a0-5efc5352ca34	98d7ba07-2dd2-42d0-819e-e438ea390565	9c5f1841-386e-40b9-aa86-b48fae5b41de	0.15	0.0300	\N	\N	f	\N	2026-07-31 11:16:00.697+00
ecd76074-df99-4c90-8e47-a228d0a1bf8c	98d7ba07-2dd2-42d0-819e-e438ea390565	c9ffa22c-9e6c-49b8-976d-053bbbb59d0e	0.15	0.0300	\N	\N	f	\N	2026-07-31 12:57:00.59484+00
785bf689-8a3b-4921-8a39-b6e3fb557768	98d7ba07-2dd2-42d0-819e-e438ea390565	168347ab-f86f-4347-b73f-dc6307fe7df3	0.15	0.0300	\N	\N	f	\N	2026-07-31 17:10:00.379873+00
44c50fb3-8c09-416d-abd7-31ee3d654f7c	98d7ba07-2dd2-42d0-819e-e438ea390565	9fd74c8d-039a-4835-9d69-6274027d22d0	0.15	0.0300	\N	\N	f	\N	2026-07-31 17:28:00.932858+00
43807eab-d90f-4220-9639-e0b73a4bcac7	98d7ba07-2dd2-42d0-819e-e438ea390565	895bc1e3-be4c-44b9-ad5a-067f54bbeeba	0.15	0.0300	\N	\N	f	\N	2026-07-31 17:33:00.098534+00
bc5ff356-b7cd-40dd-8cbd-6b6d6858499b	98d7ba07-2dd2-42d0-819e-e438ea390565	e163ad72-523b-43ba-b804-2268bb538ae5	0.15	0.0300	\N	\N	f	\N	2026-07-31 17:35:00.168549+00
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
f6416614-beac-42d9-a5db-ca7fb146e54c	98d7ba07-2dd2-42d0-819e-e438ea390565	Bktv	BC:2B:02:3A:7F:7C	\N	8140d3b1-9616-43c2-b121-2babaf4e8bf9	\N	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	2026-07-31 18:32:30.245109+00	t	2026-07-31 11:04:36.505347+00	2026-07-31 17:33:05.381367+00	199389985	478388489	0	0
\.


--
-- Data for Name: hotspot_packages; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_packages (id, isp_id, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, created_at, updated_at) FROM stdin;
6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	1 Hour	\N	5.00	1	5	5	\N	1		t	2026-07-31 10:58:50.15296+00	2026-07-31 10:58:50.15296+00
c7dbeae2-1b91-4498-a1d6-285ba3f0274d	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	24 Hours	\N	30.00	24	10	10	\N	1		t	2026-07-31 10:59:13.862091+00	2026-07-31 10:59:13.862091+00
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
f28e854b-2a0c-4d35-a659-192d512763a8	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R26	\N	active	\N	\N	\N	2026-07-31 18:48:03+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.199967+00	2026-07-31 18:09:42.199967+00	0708482861	f	f	\N	f	e4x2ce	f	\N	t	imp_1785521381983	\N
8140d3b1-9616-43c2-b121-2babaf4e8bf9	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R3	\N	active	BC:2B:02:3A:7F:7C	\N	\N	2026-07-31 18:32:30.245109+00	0	0	0	t	\N	\N	\N	2026-07-31 17:09:26.849252+00	2026-07-31 17:33:00.087291+00	254740258495	f	f	895bc1e3-be4c-44b9-ad5a-067f54bbeeba	f	35c5c4	t	BC:2B:02:3A:7F:7C	f	\N	BC:2B:02:3A:7F:7C
7cd73d4f-d55e-4e02-96b3-df0af61b2695	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R27	\N	active	\N	\N	\N	2026-07-31 20:14:31+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.20699+00	2026-07-31 18:09:42.20699+00	0721568776	f	f	\N	f	ba94cc	f	\N	t	imp_1785521381983	\N
5a8a31dc-6f09-4abe-a6da-8a2b98869b35	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R28	\N	active	\N	\N	\N	2026-07-31 19:11:01+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.215247+00	2026-07-31 18:09:42.215247+00	0745831329	f	f	\N	f	a5c7e2	f	\N	t	imp_1785521381983	\N
7eb10d62-6461-4ce8-9020-32b8fa4989d2	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	K1	\N	expired	BC:2B:02:3A:7F:7C	\N	\N	2026-07-31 12:11:41.622+00	0	0	0	f	\N	\N	\N	2026-07-31 11:15:36.836479+00	2026-07-31 12:12:00.619268+00	254740258495	f	f	e5826f3e-20c7-486b-a7c1-bb9f5fe068b6	f	98dyx4	t	BC:2B:02:3A:7F:7C	f	\N	BC:2B:02:3A:7F:7C
62eadf1b-787f-4f57-b2a9-7a35d11399e7	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R29	\N	active	\N	\N	\N	2026-08-01 17:10:32+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.22334+00	2026-07-31 18:09:42.22334+00	0743522155	f	f	\N	f	df2ead	f	\N	t	imp_1785521381983	\N
ea391d3b-721a-4059-9983-5c9e5f1c63cb	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R30	\N	active	\N	\N	\N	2026-07-31 22:59:39+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.230422+00	2026-07-31 18:09:42.230422+00	0795429825	f	f	\N	f	a26y3a	f	\N	t	imp_1785521381983	\N
8dac27c8-ac35-4479-9eb4-19738849030e	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R2	\N	expired	\N	\N	\N	2026-07-31 12:15:11.093+00	0	0	0	f	\N	\N	\N	2026-07-31 12:57:28.755836+00	2026-07-31 12:58:00.611434+00	254740258495	f	f	9c5f1841-386e-40b9-aa86-b48fae5b41de	f	by8e2c	f	\N	f	\N	\N
e9d05151-0109-41c3-bf1b-de606931d06c	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R4	\N	active	\N	\N	\N	2026-08-01 05:22:22+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:41.984651+00	2026-07-31 18:09:41.984651+00	0796829688	f	f	\N	f	a5yay5	f	\N	t	imp_1785521381983	\N
3e657627-af64-408e-81f2-d51749171da4	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R5	\N	active	\N	\N	\N	2026-08-03 08:41:56+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:41.993555+00	2026-07-31 18:09:41.993555+00	0704101213	f	f	\N	f	9cb8bb	f	\N	t	imp_1785521381983	\N
7eac945d-b556-42f2-ab70-cacfb327ee0b	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R6	\N	active	\N	\N	\N	2026-07-31 20:55:00+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.001031+00	2026-07-31 18:09:42.001031+00	0715505550	f	f	\N	f	y329a9	f	\N	t	imp_1785521381983	\N
1c713bab-8df5-4ce9-95ce-2bb8db2b72ec	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R7	\N	active	\N	\N	\N	2026-08-06 15:51:06+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.00855+00	2026-07-31 18:09:42.00855+00	0704101226	f	f	\N	f	35f536	f	\N	t	imp_1785521381983	\N
899a47cd-e06b-4fc4-b09d-7389e728f869	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R8	\N	active	\N	\N	\N	2026-07-31 22:20:31+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.015931+00	2026-07-31 18:09:42.015931+00	0745984245	f	f	\N	f	7x9546	f	\N	t	imp_1785521381983	\N
c4e53311-d505-4c6d-a3a7-ee663ffef87a	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R9	\N	active	\N	\N	\N	2026-07-31 19:31:55+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.02329+00	2026-07-31 18:09:42.02329+00	0725946805	f	f	\N	f	2y64y7	f	\N	t	imp_1785521381983	\N
38146018-ade8-4141-a8ea-a4c0ea0272dc	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R10	\N	active	\N	\N	\N	2026-08-01 04:43:30+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.032299+00	2026-07-31 18:09:42.032299+00	0727134277	f	f	\N	f	xyy556	f	\N	t	imp_1785521381983	\N
394cd952-26c1-4851-8001-79650815a175	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R31	\N	active	\N	\N	\N	2026-08-01 00:43:10+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.237896+00	2026-07-31 18:09:42.237896+00	0724733806	f	f	\N	f	bcf45b	f	\N	t	imp_1785521381983	\N
7b8d54a4-2b56-425c-971b-2d3bd77ac9da	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R11	\N	active	\N	\N	\N	2026-07-31 19:52:32+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.041411+00	2026-07-31 18:09:42.041411+00	0716353116	f	f	\N	f	y23x7e	f	\N	t	imp_1785521381983	\N
68d1e9b3-ee46-4b42-b8b6-54b2851c24e6	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R12	\N	active	\N	\N	\N	2026-07-31 19:45:53+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.048903+00	2026-07-31 18:09:42.048903+00	0726534145	f	f	\N	f	53deac	f	\N	t	imp_1785521381983	\N
9a84de80-dec3-4eb9-bf29-e009280d2ab1	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R13	\N	active	\N	\N	\N	2026-08-01 06:36:04+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.058037+00	2026-07-31 18:09:42.058037+00	0748296914	f	f	\N	f	a85fea	f	\N	t	imp_1785521381983	\N
5f31c589-18d5-4686-aa73-a377b764eacb	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R14	\N	active	\N	\N	\N	2026-08-01 07:10:57+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.096236+00	2026-07-31 18:09:42.096236+00	0797526769	f	f	\N	f	8adfy3	f	\N	t	imp_1785521381983	\N
9efb8a7f-b9ef-4173-bdaf-ef272b221164	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R15	\N	active	\N	\N	\N	2026-08-01 05:52:12+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.117396+00	2026-07-31 18:09:42.117396+00	0799512294	f	f	\N	f	4c9a5c	f	\N	t	imp_1785521381983	\N
52171a9d-bd3e-42a5-a497-6ddbd30487a5	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R16	\N	active	\N	\N	\N	2026-08-01 04:07:18+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.127959+00	2026-07-31 18:09:42.127959+00	0743205112	f	f	\N	f	ycc2a6	f	\N	t	imp_1785521381983	\N
243e908a-a51e-4eaa-aa08-d6ccca973682	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R17	\N	active	\N	\N	\N	2026-08-01 04:56:29+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.135309+00	2026-07-31 18:09:42.135309+00	0716522182	f	f	\N	f	4x2654	f	\N	t	imp_1785521381983	\N
181ba702-500c-4258-be09-daa97841234b	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R18	\N	active	\N	\N	\N	2026-08-01 04:38:35+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.142367+00	2026-07-31 18:09:42.142367+00	0758663217	f	f	\N	f	c2adcx	f	\N	t	imp_1785521381983	\N
35e19316-be1a-47f9-b216-7659235541d3	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R19	\N	active	\N	\N	\N	2026-07-31 21:48:29+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.149444+00	2026-07-31 18:09:42.149444+00	0718778949	f	f	\N	f	6785df	f	\N	t	imp_1785521381983	\N
85d15a19-273e-4b86-bfb6-93ce56fe69bc	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R20	\N	active	\N	\N	\N	2026-07-31 18:56:27+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.156679+00	2026-07-31 18:09:42.156679+00	0757951188	f	f	\N	f	c457da	f	\N	t	imp_1785521381983	\N
607237f2-425d-4a0f-927c-85c43c889be8	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R21	\N	active	\N	\N	\N	2026-08-01 09:27:06+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.163653+00	2026-07-31 18:09:42.163653+00	0797188355	f	f	\N	f	ye83b9	f	\N	t	imp_1785521381983	\N
2de6be62-6934-4d21-bb12-60800920ecaa	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R22	\N	active	\N	\N	\N	2026-08-01 16:46:16+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.170896+00	2026-07-31 18:09:42.170896+00	0704714570	f	f	\N	f	y7fd22	f	\N	t	imp_1785521381983	\N
bab92e25-584a-48b9-a49a-49476d85a5c3	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R23	\N	active	\N	\N	\N	2026-08-01 04:56:36+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.177964+00	2026-07-31 18:09:42.177964+00	0748894472	f	f	\N	f	2ecc4y	f	\N	t	imp_1785521381983	\N
429e3a35-b088-4fec-9a23-caadcd20b311	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R24	\N	active	\N	\N	\N	2026-08-01 15:06:19+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.185905+00	2026-07-31 18:09:42.185905+00	0112404681	f	f	\N	f	f6cf2y	f	\N	t	imp_1785521381983	\N
be66a93b-5926-4c61-8e04-51a282224b18	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R25	\N	active	\N	\N	\N	2026-07-31 21:26:42+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.192863+00	2026-07-31 18:09:42.192863+00	0741411885	f	f	\N	f	aaeaxc	f	\N	t	imp_1785521381983	\N
ae545ccc-5c98-43f0-8b7e-4c381dca965c	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R32	\N	active	\N	\N	\N	2026-07-31 21:16:07+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.245081+00	2026-07-31 18:09:42.245081+00	0793407946	f	f	\N	f	a896a8	f	\N	t	imp_1785521381983	\N
d751b590-66d8-4b83-9769-2da397645492	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R33	\N	active	\N	\N	\N	2026-08-01 05:33:03+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.254446+00	2026-07-31 18:09:42.254446+00	0722962879	f	f	\N	f	d7c583	f	\N	t	imp_1785521381983	\N
489dbb27-987e-4023-a3a9-c4883e973361	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R34	\N	active	\N	\N	\N	2026-08-01 06:51:22+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.262031+00	2026-07-31 18:09:42.262031+00	0740887780	f	f	\N	f	bfda29	f	\N	t	imp_1785521381983	\N
2cc05501-b4ff-4f3f-aae8-c0abf71418e8	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R35	\N	active	\N	\N	\N	2026-07-31 23:08:44+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.269848+00	2026-07-31 18:09:42.269848+00	0724616876	f	f	\N	f	e6fby9	f	\N	t	imp_1785521381983	\N
05f9375c-a69d-452d-a5e5-28c3efecb712	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R36	\N	active	\N	\N	\N	2026-08-01 16:25:47+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.277043+00	2026-07-31 18:09:42.277043+00	0745718578	f	f	\N	f	bxff43	f	\N	t	imp_1785521381983	\N
59328fdc-29db-4b8a-8ed9-c02b68b51f91	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R37	\N	active	\N	\N	\N	2026-07-31 23:06:53+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.286236+00	2026-07-31 18:09:42.286236+00	0729295508	f	f	\N	f	b2ca29	f	\N	t	imp_1785521381983	\N
3eeadb1e-7bed-44dc-bc3e-0f53f7bee801	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R38	\N	active	\N	\N	\N	2026-08-01 02:13:10+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.293896+00	2026-07-31 18:09:42.293896+00	0741086757	f	f	\N	f	x53by8	f	\N	t	imp_1785521381983	\N
a5e820c3-9f99-4190-a512-7245301457af	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R39	\N	active	\N	\N	\N	2026-07-31 20:11:06+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.301052+00	2026-07-31 18:09:42.301052+00	0710581015	f	f	\N	f	xbxy95	f	\N	t	imp_1785521381983	\N
26e8cf60-8881-4102-93de-c3e3126ce466	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R40	\N	active	\N	\N	\N	2026-07-31 21:43:08+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.308227+00	2026-07-31 18:09:42.308227+00	0726418420	f	f	\N	f	f96xab	f	\N	t	imp_1785521381983	\N
a9a72b34-cd29-4a28-9866-80ded42318f7	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R41	\N	active	\N	\N	\N	2026-07-31 21:11:25+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.31545+00	2026-07-31 18:09:42.31545+00	0711757285	f	f	\N	f	x6yxyb	f	\N	t	imp_1785521381983	\N
2e774a57-b018-478e-98c8-eb31f3c1c871	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R42	\N	active	\N	\N	\N	2026-08-01 04:21:25+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.322661+00	2026-07-31 18:09:42.322661+00	0111638647	f	f	\N	f	exd536	f	\N	t	imp_1785521381983	\N
1b8b599b-68a1-45d5-a227-05f0a03cf8a0	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R44	\N	active	\N	\N	\N	2026-08-01 15:51:57+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.344026+00	2026-07-31 18:09:42.344026+00	\N	f	f	\N	f	ae837y	f	\N	t	imp_1785521381983	\N
2d49f0c6-7acb-4afd-8d11-eb0b4366167a	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R45	\N	active	\N	\N	\N	2026-08-01 02:09:33+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.351724+00	2026-07-31 18:09:42.351724+00	0743522155	f	f	\N	f	bxf596	f	\N	t	imp_1785521381983	\N
e9fb5b5c-72ef-4c75-9527-fe43e04369fa	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R1	\N	expired	\N	\N	\N	2026-07-31 18:16:40.494425+00	0	0	0	t	\N	\N	\N	2026-07-31 11:11:28.765781+00	2026-07-31 18:16:40.494425+00	254740258495	f	f	e163ad72-523b-43ba-b804-2268bb538ae5	f	x3d6yd	f	\N	f	\N	66:87:6A:49:95:DA
4fbd326c-a219-4e08-b5b5-15bc1b5621b8	98d7ba07-2dd2-42d0-819e-e438ea390565	6a1e57da-f0e0-43f4-9a5c-4132ae1a3ddb	\N	R43	\N	active	66:87:6A:49:95:DA	\N	\N	2026-08-01 05:58:00+00	0	0	0	f	\N	\N	\N	2026-07-31 18:09:42.330473+00	2026-07-31 18:18:30.005481+00	0714649570	f	f	\N	f	a4f2f6	f	\N	t	imp_1785521381983	\N
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

COPY public.isp_payment_methods (id, isp_id, method_type, label, shortcode, consumer_key, consumer_secret, passkey, is_sandbox, use_admin_credentials, till_number, paybill_number, account_reference, bank_name, account_name, account_number, branch, forward_to_type, forward_to_number, forward_to_name, is_active, is_verified, is_default, created_at, updated_at, provider) FROM stdin;
8ff436c5-81fa-439f-a53b-2bb6104a0f2c	98d7ba07-2dd2-42d0-819e-e438ea390565	mpesa_stk	4322307	4322307	7V4yYILZxVLaYRalxSX7vLNKARpAItO9YwOzlA0pCCQ4KZQ0	b0eWBg6Cv0G558cMO6OhAbAKrJJ5wDvMAybO9axDEB1ZVastiVAAjh2HKwrz0VRw	3317f5d8845fbe32c8e8435e1b79934d36ae1c303f9383b5d8a35ac36d4720b6	f	f	\N	\N	\N	\N	\N	\N	\N	till	\N	\N	t	f	t	2026-07-31 11:11:04.244667+00	2026-07-31 11:11:04.244667+00	\N
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
3bfecbe1-2602-4881-ba5f-c1be92ccca06	98d7ba07-2dd2-42d0-819e-e438ea390565	payment	5.00	\N	5.00	IntaSend payment - UGV1311IIM	e5826f3e-20c7-486b-a7c1-bb9f5fe068b6	2026-07-31 11:12:00.57836+00
3df77d2e-1efc-4cfd-902c-736292e44bec	98d7ba07-2dd2-42d0-819e-e438ea390565	payment	5.00	\N	10.00	IntaSend payment - UGV1311EHR	9c5f1841-386e-40b9-aa86-b48fae5b41de	2026-07-31 11:16:00.71395+00
3e0bdaf5-2ec7-4a9c-a4e5-41f724526e68	98d7ba07-2dd2-42d0-819e-e438ea390565	payment	5.00	\N	15.00	IntaSend payment - UGV1311SNA	c9ffa22c-9e6c-49b8-976d-053bbbb59d0e	2026-07-31 12:57:00.60081+00
07fcd257-5898-45c8-bc79-f0c3d9ec4637	98d7ba07-2dd2-42d0-819e-e438ea390565	payment	5.00	\N	20.00	IntaSend payment - UGV13135UC	168347ab-f86f-4347-b73f-dc6307fe7df3	2026-07-31 17:10:00.392581+00
fff179c7-0697-4101-aa29-a09b5c92f2bf	98d7ba07-2dd2-42d0-819e-e438ea390565	payment	5.00	\N	25.00	IntaSend payment - UGV13136DE	9fd74c8d-039a-4835-9d69-6274027d22d0	2026-07-31 17:28:00.943244+00
a934fb5a-9f6c-4a47-8bd6-01d7e591a9d1	98d7ba07-2dd2-42d0-819e-e438ea390565	payment	5.00	\N	30.00	IntaSend payment - UGV1313C8D	895bc1e3-be4c-44b9-ad5a-067f54bbeeba	2026-07-31 17:33:00.11449+00
76935e52-438e-47a5-a1f2-fbb055982df0	98d7ba07-2dd2-42d0-819e-e438ea390565	payment	5.00	\N	35.00	IntaSend payment - UGV1313B05	e163ad72-523b-43ba-b804-2268bb538ae5	2026-07-31 17:35:00.177888+00
\.


--
-- Data for Name: isps; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isps (id, company_name, owner_name, email, phone, password_hash, plan_type, status, county, town, address, api_key, api_secret, webhook_url, wallet_balance, commission_rate, pppoe_rate_per_user, total_earned, total_commission_paid, sms_gateway, sms_api_key, sms_sender_id, logo_url, timezone, currency, email_verified, email_verify_token, password_reset_token, password_reset_expires, trial_ends_at, last_login, created_at, updated_at, sms_username, sms_partner_id, sms_api_secret, support_number, hotspot_counter, subscription_started_at, license_expires_at, billing_window_start, license_status, billing_exempt, sms_balance, phone_verified, phone_verified_at, email_verified_at) FROM stdin;
98d7ba07-2dd2-42d0-819e-e438ea390565	Rumalink	Benard Karuma	rumalinkenterprise@gmail.com	254704994652	$2a$12$pHQUP28B5A/CSP16RN.qq./pllQZPK14AbmA.iWvefoKckBe87e7S	both	active	Nairobi	Nairobi	\N	3dbfd1cc-a459-41c3-a830-1695b8256fc8	7016b41171a8eebe8d8c76543d4efc9bc7d30fea06dcb0ceeeddc68fc89de7f5	\N	35.00	0.0300	32.25	35.00	1.05	rumalink			\N	Africa/Nairobi	KES	t	\N	\N	\N	2026-08-30 10:40:54.829232+00	2026-07-31 18:03:10.667083+00	2026-07-31 10:40:54.829232+00	2026-07-31 12:56:08.19633+00	\N	\N	\N	\N	3	\N	\N	\N	trial	f	41.0000	t	2026-07-31 10:49:07.563376+00	2026-07-31 10:41:28.456365+00
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
eafea668-dc62-4779-9ffb-0937c94ee25c	98d7ba07-2dd2-42d0-819e-e438ea390565	e5826f3e-20c7-486b-a7c1-bb9f5fe068b6	ws_CO_31072026141128250740258495	4685-4c53-80cd-c502b1b6f1dd17750767	\N	\N	5.00	UGV1311IIM	254740258495	2026-07-31 11:11:41.624161+00	completed	\N	2026-07-31 11:11:28.761344+00
3fb873ab-e120-41dd-b0cd-cdcbc7dbe429	98d7ba07-2dd2-42d0-819e-e438ea390565	9c5f1841-386e-40b9-aa86-b48fae5b41de	ws_CO_31072026141453794740258495	7096-4662-9d9b-9a309cfe3b793333484	\N	\N	5.00	UGV1311EHR	254740258495	2026-07-31 11:15:11.094979+00	completed	\N	2026-07-31 11:14:53.680649+00
28e47868-c469-4990-8eac-06569f0d2292	98d7ba07-2dd2-42d0-819e-e438ea390565	c9ffa22c-9e6c-49b8-976d-053bbbb59d0e	ws_CO_31072026155647997740258495	29a0-4d51-8b04-cf456933339a11122557	\N	\N	5.00	UGV1311SNA	254740258495	2026-07-31 12:56:57.775944+00	completed	\N	2026-07-31 12:56:47.415599+00
c7c61673-5813-46e6-8365-243fe0fa1f89	98d7ba07-2dd2-42d0-819e-e438ea390565	168347ab-f86f-4347-b73f-dc6307fe7df3	ws_CO_31072026200926059740258495	1f3b-4d82-81e1-8dbb29a4d5996274421	\N	\N	5.00	UGV13135UC	254740258495	2026-07-31 17:09:48.020921+00	completed	\N	2026-07-31 17:09:26.836939+00
65a02f60-1bc4-4ab5-a448-86c4c92a248e	98d7ba07-2dd2-42d0-819e-e438ea390565	9fd74c8d-039a-4835-9d69-6274027d22d0	ws_CO_31072026202728263740258495	87ef-4d7e-89d3-a5433a7f5b311685641	\N	\N	5.00	UGV13136DE	254740258495	2026-07-31 17:27:41.131582+00	completed	\N	2026-07-31 17:27:28.205423+00
786b0d87-4d4c-460b-bc45-b281774319be	98d7ba07-2dd2-42d0-819e-e438ea390565	895bc1e3-be4c-44b9-ad5a-067f54bbeeba	ws_CO_31072026203219634740258495	506f-40a6-bda0-f8ff2ccfaa3324689912	\N	\N	5.00	UGV1313C8D	254740258495	2026-07-31 17:32:30.247634+00	completed	\N	2026-07-31 17:32:19.425649+00
45ca61df-88c4-4aba-9f3e-784730893cbe	98d7ba07-2dd2-42d0-819e-e438ea390565	e163ad72-523b-43ba-b804-2268bb538ae5	ws_CO_31072026203432790740258495	4c75-47b1-80b7-4d175a340cce3944090	\N	\N	5.00	UGV1313B05	254740258495	2026-07-31 17:34:50.987822+00	completed	\N	2026-07-31 17:34:32.537943+00
\.


--
-- Data for Name: nas; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas (id, nasname, shortname, type, ports, secret, server, community, description) FROM stdin;
1	10.8.0.2	DandoraPhase3	mikrotik	\N	RML1DEADAF1DE564565	\N	\N	RumaLink auto-sync
\.


--
-- Data for Name: nas_devices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_devices (id, isp_id, name, description, nas_ip, nas_port, secret, provision_token, provision_url, is_provisioned, provisioned_at, mikrotik_identity, mikrotik_version, mikrotik_board, mikrotik_mac, wan_ip, is_online, last_seen, hotspot_enabled, pppoe_enabled, hotspot_profile, pppoe_pool, winbox_port, created_at, updated_at, antishare_enabled, antishare_max_devices, bridged_ports, bridge_ports, hotspot_interface, pppoe_interface, gateway_ip, ip_pool_start, ip_pool_end, dns_primary, dns_secondary, hotspot_network, hotspot_gateway, hotspot_pool_start, hotspot_pool_end, mikrotik_api_user, mikrotik_api_password, remote_winbox_url, provision_step, cpu_load, memory_used_mb, memory_total_mb, disk_used_mb, disk_total_mb, uptime_seconds, wan_interface, available_interfaces, wireguard_private_key, wireguard_public_key, wireguard_ip, radius_secret, winbox_proxy_port, isp_link_status, isp_link_changed_at, isp_link_last_checked, isp_link_consecutive_failures, isp_link_notifications_enabled, multi_wan_mode, wan1_interface, wan1_gateway, wan1_ping_target, wan2_interface, wan2_gateway, wan2_ping_target, multi_wan_check_interval, multi_wan_fail_threshold, lb_weight_wan1, pcc_mode, multi_wan_applied_at, wan_quality_enabled, wan_quality_latency_ms, wan_quality_jitter_ms, wan_quality_loss_pct, wan_quality_trip_count, wan_quality_recover_count, wan_type, wan_pppoe_user, wan_pppoe_pass, wan_static_ip, wan_static_gw, wan_selected, wan_quality_min_mbps) FROM stdin;
c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	DandoraPhase3	\N	\N	3799	RML1DEADAF1DE564565	1352a858-30f3-4e68-a0e2-7945dd781fa4	https://rumalinkenterprise.online/api/provision/1352a858-30f3-4e68-a0e2-7945dd781fa4	t	2026-07-31 18:00:33.363845+00	MikroTik	7.19.6 (stable)	RB951Ui-2HnD	pending	\N	t	2026-07-31 18:20:30.486853+00	t	t	\N	\N	20001	2026-07-31 10:52:15.256785+00	2026-07-31 18:20:30.486853+00	f	1	["ether2", "ether3", "ether4", "wlan1"]	ether3,ether4,ether5	bridge1	ether1	192.168.88.1	192.168.88.10	192.168.88.254	8.8.8.8	8.8.4.4	10.100.0.0/24	10.100.0.1	10.100.0.10	10.100.0.250	rl_c9ef146c	16e442bb-9ec	rumalinkenterprise.online:20001	configured	8	61	128	22	128	0	ether2	ether1,ether2,ether3,ether4,ether5	+IK0Hq1qBxovU8Z9STYNCINpLtar7gOhEKzAeXgf52c=	jXRTE14+/79jTjVxgmo5a60vA62nB0AtghYfZNCs1QE=	10.8.0.2	RML1DEADAF1DE564565	\N	up	\N	2026-07-31 18:21:02.657+00	0	t	failover	\N	\N	8.8.8.8	\N	\N	1.1.1.1	10	3	50	both-addresses	2026-07-31 10:54:48.512152+00	t	150	60	2	4	4	pppoe	mikrotiktest2	mikrotik2541028	\N	\N	t	3
\.


--
-- Data for Name: nas_events; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_events (id, nas_id, isp_id, event_type, message, created_at) FROM stdin;
63d32af3-1133-4870-8523-0f1223d79ed6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	provisioned	Config imported	2026-07-31 10:52:27.748237+00
cba72d62-8be7-4020-8dbc-d079390e2fad	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:55:26.565079+00
613d1a83-0812-47cc-b66b-aff1c96cd95c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:55:41.69779+00
97c6a2b7-8ea7-417f-93b0-7e8e2f8df812	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:56:14.039779+00
58f4108b-8f90-4629-83ad-4eef37140ba4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:56:41.812382+00
4d6d7de3-c48e-40f4-9e3c-acd2ffc6477e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:57:13.617108+00
a346216d-cb75-436c-95e2-2959db32e635	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:57:41.765217+00
96dbda02-ca27-4f04-872e-e1ab774355e9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:58:13.840356+00
5a1c2302-0ca6-44d2-a97f-a180bad8792b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:58:51.36078+00
73fe5f62-9429-48fe-a603-22d2f49e4692	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:59:29.389728+00
8963e51e-3605-4d3a-a262-974ccecaa24f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 10:59:57.685065+00
fd221aa9-3a40-4cfe-8cc3-5ed4c556dbfc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:00:29.323636+00
bb35fd46-37b2-4f40-b9ac-d753025a2bec	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:00:57.947711+00
eb89a2e3-0576-4755-a0cb-e1d57dd2c64d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:01:29.178417+00
2fc230cb-d3ef-4108-98f6-4ee93efb1984	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:01:58.818061+00
a8af2c54-3f14-4b3d-8126-16df2611a031	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:02:39.164668+00
1664083d-ba7d-47ca-9196-2b585007c45c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:03:14.201834+00
86da11e1-218f-4ab1-84e6-9ac97c897d54	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:03:42.273225+00
3420d530-faf7-4af8-8b41-0c48d7d377ac	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:04:16.43746+00
66251e85-d0da-4c8d-ad12-c4b1f043b644	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:04:57.593054+00
83c22ca9-dbe3-4afa-805c-7dd44a3d2eee	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:05:30.814691+00
a1faf70e-4a09-4c2a-8a36-4b52a75aefbc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:06:16.406602+00
1b4b925e-a7c8-4155-8f86-d9c8d8ca3825	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:06:58.018173+00
4e046af3-3a4c-4aa7-ab7b-d0f5ef29c450	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:07:29.336388+00
a3148b45-dd50-48f8-a65c-17e7267b508b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:07:56.973547+00
b936de1b-a085-4256-a666-ab4dd734c648	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:08:29.473154+00
31b6f6f9-a247-4c20-a027-1e9f57e8ee60	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:08:56.624971+00
ef859594-21ee-4344-a5a3-e4b124862ebd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:09:29.750546+00
d5316e7e-721e-4669-b509-d69e9deda599	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:09:57.628583+00
e209f7e8-86f5-4ea6-97db-44fbb5e6bdfa	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:10:40.41239+00
ede21aab-10f9-45b7-99e1-29ea09ba5c5a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:11:14.38486+00
30cb570a-edf9-43ba-94ba-a766922824a1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:11:52.05568+00
26eebe97-011f-46d4-9a33-55f8f28f00f4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:12:29.903687+00
9a2d0602-92ce-4351-ae52-6d992bad27fe	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:12:58.408801+00
00956150-cec1-44e5-8418-ba263d57e7d8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:13:31.604377+00
26b11bf4-2519-4810-bac5-84dfb648b848	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:14:14.828278+00
437d916c-b47b-4bf5-b1d7-08c146b6969e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:14:42.98606+00
78a365c8-036e-4216-b99b-ed35e9afbc41	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:15:16.564296+00
34a23538-37b2-4138-bd7f-a3f5c96f7259	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:15:57.851812+00
783ecbf4-e110-42c5-9eb6-cfaa7f1f61ef	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:16:32.089746+00
48ce4fe1-11f8-4c1c-8442-ac4fa8f1fce4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:17:24.372708+00
02208abe-8fd3-447e-b565-c148a6872793	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:17:57.929492+00
053cb934-e250-4952-8d71-6733e63c6343	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:18:29.98589+00
ba2b3b76-29d8-4f07-a660-e5aac494197b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:18:58.066364+00
2844fac3-5123-4453-9e96-67d80688ec7d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:19:30.59623+00
0ca0d69c-9dd7-40e9-a51b-53293039dd04	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:20:13.903402+00
8e692a61-5d95-4c5e-a39f-33d04309a6ae	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:20:43.197453+00
91fbf23d-ba30-4d09-82e6-20da3c8db889	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:21:12.862415+00
006e4a56-952f-499d-ba31-e16c347c139d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:21:41.992154+00
a055fa54-0673-40d0-9f88-99158647b5e8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:22:14.357232+00
6e6404af-9c0f-49f5-bad4-f6486f4ea52d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:22:42.129517+00
fd92540f-f317-4582-82c8-2373c65647ba	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:23:13.803504+00
348d66a1-73d5-45e3-b689-5c4696f4932e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:23:42.05759+00
fa776348-1131-41e1-9d5f-079e80da356e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:24:13.999318+00
3afd9840-727d-4750-818d-a8e847ae8f53	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:24:43.403557+00
4de51ff7-e456-424f-ad60-b7082cef20c1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:25:14.609677+00
d1cf6d7b-277b-4c75-936b-d60f2ea5b7a1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:25:43.478836+00
cc75d7fa-d482-41e0-a55f-88c5c4bc89e4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:26:23.408615+00
e64cc669-5942-4781-96c2-58ebaa2d3e0b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:27:10.431049+00
02f9ffcf-9b9c-417b-acf6-e7bf1c935b2f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:27:53.287431+00
a4789fb5-1f22-4d0c-8a20-a28518067560	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:28:30.748938+00
c12f12fa-317b-4993-8c6e-b9566c9d50e7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:29:14.229499+00
75b68bcf-cc26-47c3-995f-f30b3028b407	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:29:42.287245+00
e3d0000d-e42a-45d5-8bcf-2649eb2bd1e8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:30:23.341758+00
6782d779-a29a-4ab4-a910-47131fe8ec2d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:30:58.389292+00
a2894f15-85b9-4615-87f2-8141be935ad0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:31:29.860634+00
fcd3b7d9-1a05-4c99-955e-2215e0593321	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:31:57.547515+00
768807c7-3e17-4df3-b86c-169cfbec5b38	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:32:29.652669+00
1828dd96-1cf6-4b8a-9523-9d2655a18cfa	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:32:57.593784+00
826beb66-f9a2-47c0-abf8-2cffd3bd93f7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:33:28.860873+00
26e0a49a-0ea4-4d80-87cd-4f960f64bfa5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:34:08.465109+00
f7198de8-1439-414c-b11f-050b86bcc120	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:34:42.674086+00
7a0a9df5-68e5-481c-8de3-07ba9b1f6ceb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:35:14.056956+00
23ad30ee-1bff-4442-bb9e-f4d1aed07d80	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:35:42.923395+00
625b57eb-5e04-4af5-90ae-a71bbdee0509	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:36:14.308332+00
b9700121-76d4-4691-beb5-dcf9f26a209c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:36:42.423058+00
1133a6f0-fe16-4b6f-b2ce-84fe9c3753a5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:37:18.907434+00
69c6c313-25fe-4163-a174-85bc07523a81	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:37:58.059819+00
b6f2ef6f-314e-4636-bca1-557e100bd0f7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:38:29.534789+00
660742a6-1046-4c55-bc4b-fd527173260a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:38:58.04905+00
b84b1cb4-615f-4850-9abe-045049d5dc72	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:39:29.543554+00
19fd80db-7087-4840-890c-d56c8f6f2b36	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:39:58.585616+00
f7a6ade8-d8f5-4424-97a6-310b2b052122	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:40:39.006607+00
48b8136a-ed59-4c71-aeff-36456efb4bae	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:41:14.444782+00
4b53a634-0e2f-41a5-8892-e2d44feaa701	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:41:42.728783+00
d17a24ce-619e-408c-9e3c-b611cc0fb507	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:42:25.264826+00
c303e44a-f451-4030-9269-6eeb42f700ed	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:42:58.146531+00
31584e38-0b1a-4c0e-975a-36edf6ad9035	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:43:29.864198+00
917af844-eeb6-4481-8b1f-ca456c96ab4b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:43:58.002794+00
93b08205-6877-4996-9d60-f8e1d61cbe3f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:44:29.835594+00
4cf51c46-3455-4aac-a25b-09aea97e64db	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:44:57.977756+00
ead2e319-8230-4b40-b5a7-7747b6706d31	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:45:29.706695+00
0d8ce21c-e79b-4cc6-a839-b134941d07a2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:45:58.071679+00
b56ee653-d515-465b-8925-1dc0f931f265	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:46:29.787682+00
b82f818e-fdc8-402b-96d3-48662d7bc37e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:46:58.265708+00
6877216f-3a27-4784-8eb5-ff8b2d1d5d84	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:47:30.864692+00
cc57b46c-066a-473c-82ea-eb894dc0167c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:48:16.970461+00
8b3bb1b2-6f4c-47ef-b716-b843036dc876	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:48:57.915063+00
f91fd09d-ac25-474b-9acf-39b6ae995b45	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:49:38.731244+00
9ce78433-05e5-42fd-971b-affbac275bf3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:50:13.7423+00
ccac4096-59c1-43d8-ba0b-4aa5b253a403	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:50:42.990521+00
74898fe7-78e4-41d4-9382-25b2e9d403a8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:51:14.473099+00
b548db0b-56b8-4a23-b527-c59e2a5b356e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:51:43.650182+00
193e027a-dd66-4fe5-bbf2-3d4abc4fca63	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:52:17.09613+00
240af414-5900-447a-9336-8e253acefda8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:52:58.123462+00
2a4cdc1e-1753-46f6-a743-235e1f071719	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:53:30.472252+00
c71f9995-059d-43b4-abe4-81ef9e571973	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:54:30.141147+00
78f93c6c-a672-45e1-9f29-a6c364bb9b6d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:54:57.908388+00
897124ad-e85a-4259-a89e-e239d21b24c6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:55:39.40693+00
c9edc6ae-b985-4c0b-a782-6d5b18d1cc67	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:56:15.254475+00
0b04f8eb-9091-4f6e-a6e1-fe13961f1a4f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:56:43.357138+00
0e9681cc-c689-4920-a10b-fe283e708a6c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:57:23.853752+00
6f783d7b-0e4d-4ad6-8999-5faae0db5c70	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:57:59.947025+00
0131d0de-3bae-4688-b2e0-aa9bfec91ebf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:58:44.09305+00
fb8da761-83aa-4a26-bc5a-cf1e04de7e22	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:59:16.795071+00
7e4bb2fb-8825-4abb-b7ed-1b2cba32d04a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 11:59:57.306118+00
b57c248f-ebb7-45cc-912c-3aa7a3e7d3b2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:00:28.629774+00
441e3309-6cbd-4582-aabe-a65e30d00ed1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:00:57.799617+00
2570be2f-5ee2-4960-956a-b90d28b34c51	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:01:28.214413+00
072a606c-6352-40fa-ab47-685d710f0a5d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:01:56.147073+00
749a76da-e66d-49a2-9703-ac0b9755634a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:02:28.250296+00
e1f89004-b267-4d3b-b76a-21cd61e1739c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:02:57.17071+00
b1370106-8afa-4246-8bc1-77cb2c9b5d9b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:03:29.263362+00
d8ba3ef6-3aba-4421-9cfc-95f3a5bcf560	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:03:57.441705+00
49391ce3-4e62-45c1-a988-ea938efc0471	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:04:48.170074+00
cdd11ad3-726d-4faf-85d2-6e0ff8c6c23a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:05:39.010165+00
cfbb4e10-ffcb-4102-bff9-8284acb92c59	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:06:17.350815+00
9c4b8bd8-1b9e-46ca-9dfb-85d86ba80ec2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:06:58.679256+00
368f1ac4-0d54-48ca-bcde-ad3f3a25d91c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:07:28.456715+00
8e34ade5-c876-40c2-a6cd-70cdac6caaf1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:07:57.599345+00
b73326af-db37-4fd6-a2dd-df7e88c8cefa	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:08:33.004506+00
50782246-6ef2-41ab-8a1a-9d21cefc7cde	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:09:17.244797+00
b47c05a4-a31f-429d-9e0a-271f9951b988	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:09:56.721243+00
041a95da-ef32-45b4-9cba-a8a52feb96b7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:10:29.78805+00
41d3c429-270c-4a37-98d4-6fde15853eaf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:10:58.030918+00
c13e7e2b-0bde-4965-bd1d-ad6e156a6132	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:11:29.834708+00
1cabac37-6fe6-4346-9021-2c36e4240b1d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:11:58.220594+00
41166337-9329-4dcd-b22e-e39b647256dc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:12:29.695177+00
5b843a56-9ff1-4e71-b989-b8087765f8f1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:12:58.159654+00
5a72e8fa-644e-44d3-b699-e1b3a593774c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:13:29.635792+00
a3a95286-6e64-47fb-9ca6-af04f339788a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:13:58.186259+00
c9da700d-b8c3-4e6f-9349-fd0b99fe6ac2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:14:57.423428+00
0deb1058-eb65-40fd-a1e7-c196e16afea8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:15:39.371167+00
60781d15-75cd-4abe-9256-b971d2a8aae5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:16:16.829241+00
8592f70f-4e09-41a0-981c-4d80fe5f16bf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:17:11.984114+00
5f6c53ce-6d32-4d6b-8a17-3900088d2f08	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:18:17.000819+00
83bb4be1-0c29-4421-89d8-e9d927bd1787	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:18:59.699052+00
38496005-e7a9-49a9-9210-8a6aa92053bb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:19:30.974581+00
d2fdbf01-6ca4-4bd5-99ab-07fc7e12358d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:20:14.303108+00
41e05561-f286-4865-8125-736e2c41382e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:20:42.779171+00
b0539921-fca6-4e32-9bc8-1af162137c78	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:21:14.395033+00
a9e01cd2-c994-4f19-a321-a910e79199ea	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:21:42.794744+00
d3e0bc27-4fab-4df8-86a4-825e95a60428	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:22:14.199829+00
82b5e6ca-884d-4eaf-bb33-8317f499dc04	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:22:43.122167+00
1e8b627a-e184-47b7-be55-3295a1a22538	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:23:14.495744+00
40164d6d-ec0c-4cb8-89ad-3c68de2971e0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:23:58.951877+00
b0a57ebb-4598-4b72-ae3a-970def377f21	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:24:29.986117+00
84e518fc-bf60-4309-ab53-e56ba65346b6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:24:57.902586+00
3f178fbc-4223-411f-8f1b-fc9b3e932cd1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:25:30.18005+00
6715b4c1-e187-4a57-9047-0548caa0fbe8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:25:58.54965+00
d25bf7f7-4cad-4a7d-bf97-4f5e075beabc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:26:29.830743+00
f13a9723-7c3a-47f4-9f86-f247e3b12592	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:26:58.079923+00
6cb3c3c9-22a6-4d2b-813c-ea9e78341067	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:27:30.182778+00
ed723995-fdc4-4c10-969e-172313e56d8e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:27:58.752465+00
12713f4d-b397-41c5-b220-4f25ac365d45	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:28:30.026663+00
5b66e9a4-2c39-460d-a4fb-ed54403f07d9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:28:58.229325+00
d57d9c2b-da98-4904-a4f9-b1e526dc90d8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:29:42.819132+00
a6672ef3-9cc4-4f9b-a472-f53ab1f78435	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:30:17.458471+00
9ddbec52-4311-4fa7-a3a2-2a70f7455f6b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:30:58.764532+00
33dd0d96-63ee-4993-9889-59fd74869ff6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:31:30.189886+00
1c3ababa-96ef-4f58-8e5e-bcfca2d08698	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:31:58.107813+00
1d7d1172-cd2a-4f40-83e5-48d5f19db1b6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:32:29.564073+00
e307791b-a291-4bc1-a7d8-723e618c256a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:32:59.105705+00
a1589d0f-5e36-401e-82c6-e56be2095c3a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:33:30.176965+00
0d59ab5c-32f5-49d2-a6a6-584700b8ddac	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:34:10.19562+00
715e72e8-c4f3-4b87-a59b-9e8b19a69189	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:34:43.315861+00
bcc396c2-83b0-452f-8e10-7310b59a3fbe	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:35:24.200409+00
4084d485-94a4-4863-b64a-a3ef56a64fdf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:35:57.997534+00
031bce59-7834-4d00-baaa-b2747f24723f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:36:39.302595+00
e46ca138-cc65-443e-a41e-a840b671e9cc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:37:16.356175+00
2af0a1c4-236b-43d5-8ac6-b2ce807d47e0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:38:08.870356+00
f9faaa39-8c7a-4467-83ac-000f0fa82792	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:38:43.235497+00
4edf591f-b023-436f-b155-8e95104e0fb6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:39:16.266845+00
6c426c57-96a5-4411-8e62-b29ca17257de	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:40:00.084584+00
13864bd7-4858-4734-bb6a-22e223145315	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:40:39.128325+00
497d39c4-d112-4937-aea4-534151524245	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:41:16.324126+00
b18355e8-4127-45b3-8f9a-48b788a402d3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:41:57.705462+00
cd9bcbb4-e1d6-4c68-8ce0-52ef55f526da	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:42:30.45696+00
75dc0dbf-4e9f-4819-8ab1-344e1087525f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:43:16.946834+00
c39f110c-49a8-4b87-9d24-bd6f5109c15b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:43:58.19849+00
e4125068-5302-4337-9d47-32bd6f1a400b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:44:29.407241+00
780867c5-3dc2-4e33-b068-0b23ad0b0360	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:44:57.448035+00
65e9ebe0-b912-4301-8970-d9b4d10febc9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:45:29.952106+00
aa4c7daa-c0f9-49bf-ba64-032a94aaf8c3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:45:58.531725+00
83c07644-9fe8-4b29-8b08-ae0203c3f6c5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:46:30.015648+00
bb76e7a3-34c6-43df-babe-bb514a7d11d9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:46:57.534978+00
4c66a113-f362-497d-8069-4037e0833c52	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:47:29.990423+00
c5c33f12-cc80-4d6c-babd-d356e44d5b03	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:47:57.694172+00
f6fb2feb-5f7f-4340-895e-982990d27a7c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:48:28.493971+00
a7d0b1dc-983c-47c3-9b12-cb8e98c13631	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:48:57.738865+00
07e0b0e7-8597-474d-8a21-db7c6d0dbf51	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:49:28.504739+00
c8e48033-b270-4650-b046-96cc2398c645	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:49:58.217919+00
74b62166-9f59-4e67-a9d9-d8d778cae318	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:50:31.649537+00
39ff0492-713b-4a0b-b3c8-5e71cebcc43a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:51:16.809353+00
03abfcb9-da31-497f-ae60-7d3ab461c0d6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:51:57.783301+00
35e2d1a0-6ba4-4b74-9cee-6b6623e19e5f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:52:29.861201+00
42274909-64f5-462a-be61-d0573d77a337	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:53:09.447438+00
9155fca7-bb69-413b-9980-3131ce08bf86	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:53:42.999622+00
072cef07-1849-448d-80a6-fc92ecb224df	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:54:14.312309+00
1da01b53-3f45-48fd-8930-ef99bc1c669e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:54:42.596491+00
f72eb353-5cac-4352-9498-41cee586ec7e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:55:14.80806+00
1346916d-6e8c-4dbe-a0d4-340aa6f4cf69	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:55:42.805651+00
f48abecb-6d93-4dd0-a656-0855a9c559c8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:56:14.548911+00
8d3c0853-3207-4983-8845-1ef849dcce54	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:56:42.653976+00
d58182a0-dce6-4f18-8d19-86bc5e0e8bc1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:57:14.41581+00
a85dd70a-62b2-4571-9bd3-7bd56a3a17de	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:57:43.251177+00
db192a3b-0de1-408d-a82f-3c15cc4e1695	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:58:14.427527+00
25d9a379-602f-437a-b0de-bede646b9e6a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:58:42.929919+00
ed2960b0-deb7-4adf-8492-5f32be9a2b06	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 12:59:14.426975+00
af1d20e8-d739-4d70-9abf-94db52e11808	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:01:08.475132+00
8ee5d3d6-a57c-4f80-8d48-7f2970a127bb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:01:58.577116+00
af9d0dc7-b13e-48af-87c5-f4aaad7ac02f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:02:31.524939+00
0c8e11a8-1a7b-420c-8c36-d03bf82e061b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:03:14.880635+00
9fbcda11-53ff-4ef0-baa4-a4d958412573	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:03:43.055114+00
b2b1b3d2-e652-4f3e-9aab-3e0cac35911c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:04:14.761838+00
211dc1bd-9264-47f3-bb3e-e4e4bb4d17fc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:04:42.877823+00
454f59c8-0603-4002-80c3-67df17b291fe	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:05:24.946849+00
644586c7-a6d7-47e9-9e3a-88517b87340d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:05:58.09452+00
0643e773-19a9-45b1-bf9a-bdaf73397eb6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:06:30.257677+00
2fe6139a-939f-4c6f-b1aa-fe0dcf7c871b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:06:58.138419+00
7f23365a-8711-4825-b602-ac7dc96ea6f0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:07:38.529747+00
8cf2e86f-6946-47a9-8b8b-dcefb9258d36	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:08:14.936638+00
2351c5dd-4c31-4843-9007-85bb210fc770	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:08:43.139042+00
80c16238-fb07-4ae6-b80b-14a7887e862c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:09:14.708811+00
84305a36-10a2-4bcf-b526-61e27b66ebd0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:09:43.189632+00
cee0eb0e-9997-489c-9047-ae9bdaf4f188	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:10:14.946095+00
c63e414d-96ed-4eb5-afd6-ca5e188561b7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:10:43.005871+00
5d9df96b-0fe9-42d9-8640-98421a23c8bf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:11:15.158153+00
b5c847fc-47f1-430f-b651-3503af035bc4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:11:43.235599+00
e3f1913f-fdf3-40b0-9d98-888715d528cb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:12:16.872043+00
faa9e63f-30da-4aae-ac42-10ee417a5463	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:12:58.785623+00
2d45484c-a512-4645-8746-d754797b0453	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:13:29.419221+00
6c8f5bc4-836f-4d75-b9fa-cc101dcd671a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:13:56.364994+00
01651892-9a84-4741-ba73-194deb13d72f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:14:29.284863+00
dd20ca71-d17f-4dcb-b44e-7b8809f75b68	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:14:57.367137+00
7236dc4b-5230-4b93-8372-d83aff21cba2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:15:30.238365+00
6101e253-53c1-4ecd-ab27-02c515e2e02e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:16:14.192426+00
3bd63427-bc20-49db-bf2f-a27cd56fd593	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:16:42.203178+00
cc4849d7-b6ca-4ca1-b799-0f2a79b40510	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:17:13.937711+00
e910376b-7b85-4c11-83c6-6ac9d390e267	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:17:42.536337+00
0079939e-e6bd-4a14-9962-41fc4d0173f3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:18:16.333774+00
354f046e-11af-4283-baeb-ee7e6ea90474	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:18:57.89745+00
e23a370f-6fb3-4f6f-bc53-6edd07b7a444	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:19:29.41028+00
bec2112a-c401-4d0d-ac94-15f605f70e2b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:19:57.229921+00
95170ce3-2a93-42bf-a6d4-490012d12bec	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:20:29.399375+00
56a8b1c6-8da7-4f41-a46e-83f87273bd76	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:20:57.29872+00
014eb577-cc72-40b9-b087-212ee8da6678	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:21:28.344944+00
dcd6d8e1-f30f-421e-8489-21d39112a502	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:21:57.4835+00
cd7fc7ac-b2ed-4439-aca0-4922dc8ee7be	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:22:31.388846+00
c4d96dd8-01a5-4686-a4bd-28781527fcf1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:23:16.656139+00
d12a81d3-e099-4fad-ab6d-fd35072dcaec	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:23:57.624486+00
f2238514-6a13-43de-b138-18bfb4de82e7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:24:29.477747+00
9f3d8dc0-1ebf-4a37-9169-4512300c544f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:24:56.411528+00
1c532a14-958b-4523-9910-ed57ac6a4b85	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:25:29.794098+00
e3af70d8-c559-4219-bdba-5a77e731ddfb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:25:57.685088+00
4728c44e-cba7-4a22-8f66-eb434929d03c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:26:29.543894+00
52a8c32a-b2cd-4ac9-8acd-1e9bb3758766	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:26:57.45725+00
2098bbec-d541-4c1a-b98f-f655aa6bc5f9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:27:29.775739+00
78606a85-ae8f-452c-9c78-fef99fb579cd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:27:57.519859+00
15824af8-4836-4d4b-98ae-86c18ada1d41	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:28:29.587218+00
4feff9fb-517c-4640-9dfd-cc44c6b00613	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:28:57.497257+00
95df1099-3b0b-4426-ab57-ae59723037d9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:29:29.780679+00
4abb79f4-8182-417b-a377-7c4788613369	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:29:57.698639+00
a9d49f90-1357-48ad-b8de-d87243b96a6f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:30:29.682911+00
5d87f4ed-6d77-4307-83e0-dce793008790	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:30:57.509269+00
4ecf9cc3-f209-4efe-b274-da68f9d9a8a8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:31:29.819417+00
53d5a6fe-6eac-4f9a-b80a-c4f47c635580	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:31:57.729991+00
6c62e5b1-b55b-438a-9dda-630c8bc09303	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:32:29.724546+00
1a266803-9abd-421a-a264-a04ca36d3081	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:32:59.539137+00
4d06f77a-54f7-4641-b1dc-5a14c216cf0a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:33:30.191243+00
041df2c6-8470-481c-94e9-6d774124fde0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:33:58.680949+00
93818787-f8ce-4bce-8353-389776735df6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:34:29.751585+00
9f0cc3bc-3b85-4059-8994-39c768bb4288	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:34:57.826227+00
a17400a5-07b3-420a-9000-efc755bf90ca	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:35:29.968148+00
66dac4df-4303-4a2b-bb14-1f456261622d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:35:57.85538+00
0202844e-18b2-4826-9aa1-468580b9b757	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:36:29.857101+00
d1382247-4dba-4b69-b6c1-979872970a96	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:36:58.139585+00
4266728c-7faf-48c3-b31f-d6b3aac2107c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:37:29.965702+00
93fd427c-7db3-4851-800a-c86cf5b3df74	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:37:57.79101+00
f9aeb3ae-ce65-407d-8b23-3760f7fc3527	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:38:29.851256+00
d9f2e682-1106-4892-8a16-8a15c97c00ef	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:38:57.946775+00
8c6a0b7f-3d66-4c0e-a7e2-2e52a1be2fd1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:39:29.98491+00
46dc006b-bb22-43c3-ac90-32354cb512ac	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:39:58.062671+00
be406e1f-a309-4f4f-bfaf-a179f154a19e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:40:30.045524+00
2b1df9a4-d49d-48ca-ac37-928224cc5f23	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:40:57.059508+00
6a95568c-5e43-4acd-a080-3a7e6d61657b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:41:30.173191+00
ab68b413-516d-4c1a-ae2d-fdb9b7848e87	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:41:58.096067+00
a15ef5f5-6740-45ce-9d89-f37df432e5dc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:42:30.042407+00
0b8db3a2-bf5d-4124-8cbd-a527d345442e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:42:57.910107+00
0e988bc9-6f8d-4aae-aa53-1e201a40613f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:43:30.981867+00
d9b3c625-61ea-4967-b3bd-25785ac0bec6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:44:16.200103+00
46e51e2e-91d8-4494-89e7-a9a7628d6fcf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:44:57.212996+00
b3c1f4c7-45e8-4cf5-b688-0ea01e886838	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:45:28.12152+00
aabb1e4d-ce1a-4f05-8a65-2cf556e21a4b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:45:56.196523+00
4885c6d1-ca4f-4230-9fd8-f45eefa40475	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:46:28.231825+00
38855342-c726-4506-a5ec-4af73ab80111	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:46:56.053441+00
697eefc6-964c-4375-b382-0a8815bb927f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:47:28.190728+00
875d9cf3-bf83-4639-bd02-e27cf1a285e5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:47:56.397986+00
2d86448c-bba9-42a1-9816-984b23e61fca	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:48:28.287661+00
a86427e4-b233-40c2-b99b-67abe1c28b49	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:48:56.35101+00
3a9717c2-75f6-4f77-9791-aa22b9241503	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:49:29.597775+00
f55015ac-c672-4bec-bb06-5debbfb603a0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:49:56.37345+00
4cdb25dd-16e6-41d2-aa35-696f64794ea5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:50:28.313905+00
7ceabe87-2d6c-474b-8e05-070767fa2cbd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:50:56.391114+00
888b4510-e152-4364-85f6-c8425430c439	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:51:28.358427+00
07ffa175-1867-4a39-8219-6a9766fcfdca	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:51:56.285798+00
8752c69b-5c20-43fd-b4f7-d0b83b2d1b51	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:52:28.609625+00
24135cf3-b11b-4286-a5a1-f005fbdefeef	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:52:56.273813+00
c0cc0297-c44b-406a-86eb-4c38d3f5b5b9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:53:30.462748+00
2a7d13da-941f-46d2-872f-d730b54e5521	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:54:15.076628+00
0c2e32ed-81c7-4090-8c8e-b9a592efa1e8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:54:41.751019+00
903ff7f2-f3cd-4687-8581-6eb43bb8888d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:55:13.202907+00
89074c0b-3e3e-4b15-8db0-84d610d87a51	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:55:41.392602+00
7ab741da-dcc7-467b-beb0-ed411e59aff9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:56:13.274107+00
25da90df-808c-4dc2-b540-a5d73ba90fbf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:56:41.32139+00
e76f199c-e174-47a3-b928-02f2ee1887a0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:57:13.274012+00
1cade315-ef4a-4a61-8cda-01ef503e0148	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:57:41.433003+00
85f0ae92-4635-416d-b7a6-957ecd8cea61	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:58:13.25853+00
83271720-a9e0-4641-a583-859f66515011	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:58:41.387117+00
2d08c18c-5022-4ea8-a312-ff9bdef93047	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:59:13.309062+00
68d0d651-67c3-4888-a853-23c6987d9ed2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 13:59:41.566098+00
54500271-6e94-46f8-ac58-fab0b8a709f4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:00:14.289886+00
3e05b9d6-f816-42cd-b3ea-40e09c1ff4e8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:00:42.640265+00
058da4c0-0426-4ac5-a5c5-917dc385569d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:01:14.34977+00
73574b18-d2d1-4597-9da2-1b925cd98130	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:01:42.843635+00
21a880a2-dac0-4a08-978f-b9c1894f3790	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:02:14.191088+00
80ea4dfa-1716-4c61-9f19-e31ee05ba0ed	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:02:42.671074+00
c6e658b1-cf90-4374-b780-50a571cbba88	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:03:14.18578+00
ebc23dcd-36e2-4f72-ac5c-7a45b4451437	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:03:42.829611+00
29e9cdd9-a1c5-47a1-93f1-faeb6020a8d3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:04:14.401204+00
773224c1-c45b-420a-898f-9cfabbcf2e88	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:04:43.576597+00
20e3c71f-ab33-4a75-844f-8271f0e99a1f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:05:16.770794+00
4bef704e-8d11-4789-aeb3-e04a404c37ba	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:05:57.835541+00
06832bfc-c258-407d-8d97-f39299099b95	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:06:29.66839+00
83454c0c-9811-470e-b8e5-fd7edd26260f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:06:57.777377+00
95eb9b89-c59c-4346-865c-af956d1801d0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:07:29.76858+00
5e12d066-4bff-48aa-9c18-24b4e00c71f4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:07:57.850799+00
7d777981-9926-4164-909c-4f06362dc0fd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:08:29.719045+00
80af86a7-f1a3-4d74-8c94-9ca392c1b5b9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:08:58.856359+00
6c676b8d-7095-409e-8d72-4830c8d14185	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:09:29.779667+00
42159714-909a-4e98-bde0-6b793a4e5d68	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:09:56.669008+00
8aa923e2-a2d0-4feb-b9ac-fb76c5b66bb4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:10:29.740997+00
44335f8b-aa85-497f-8d7c-dfaf40c35dde	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:10:57.877705+00
6987376b-4db0-4107-b65e-2b93e51a0257	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:11:29.974254+00
fb867e8d-5b3d-4a1d-9c5d-ac8b1a7ade45	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:11:58.327728+00
c7e299aa-92e6-44b0-8240-df255379e705	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:12:29.860701+00
936f9a13-dc27-4798-a248-e5db84c7cb97	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:12:57.929782+00
50013604-299c-4048-b348-26ffaf60e5b7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:13:29.763537+00
6d7e9c42-c6ae-49ba-bc6c-31e66ac3f4e6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:13:57.948685+00
a1cba351-c61a-4ec9-ab9e-71d9402c542a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:14:30.875536+00
3b63a748-aca7-4147-8fb6-3fc2202afb91	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:15:16.757692+00
b5eab850-3aeb-4655-b0ec-70d36d54f25a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:15:58.560417+00
a4a1f6af-43d4-4a7d-828f-ff35c6b5f21a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:16:29.859534+00
5567a0de-fe21-4dd5-b224-2ce840c9e9a9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:16:57.836581+00
b4e83bdc-a55b-4e24-89b4-4c362fcbd604	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:17:29.964696+00
80ac8bb3-f48b-4d2f-b3f1-49a749544570	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:18:14.771297+00
de51ff8c-7a60-4240-b761-017bd9843637	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:18:41.835221+00
12fc4b48-a4d7-414c-9488-1c0ad4e6916c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:19:14.850389+00
f907c4a3-bb1d-4fac-a8ea-92a28161d1e4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:19:43.016836+00
36763064-cc8b-4531-acdb-a9253529e9df	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:20:14.602969+00
e5b8aa55-7055-4e52-bb51-2030fc6822a1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:20:43.138415+00
a8a705f2-f450-41c1-90be-6aa8a883c277	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:21:24.213572+00
ae19f580-0734-44d4-a817-b33a4a2d04b2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:21:58.205687+00
85a69c58-b837-48f5-8d5f-660db79f5898	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:22:30.096067+00
c80f8e5d-864a-41ab-8beb-405aede2d745	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:22:58.171255+00
e609ad40-0848-4ae6-8f2d-31aa7f518a67	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:23:30.641494+00
780ea719-130d-4a87-9c28-56508f6a8479	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:24:14.209127+00
73e77e87-396e-4ddf-9104-202f7a71c7ef	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:24:42.323701+00
57db3f4b-7683-441c-a27f-44525916bbaf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:25:14.07548+00
baeacc28-8e13-480a-9cc4-c85256de5062	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:25:44.370157+00
cbf570b2-d1c9-431f-8421-79eae60aad95	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:26:16.626646+00
f1d5df49-0886-4136-b56a-72912d202545	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:26:58.661681+00
52835ae9-be94-41e6-a8dc-8d60ad282a9b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:27:29.61184+00
3cf8db58-d59e-4b21-bbdf-3600f894a245	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:27:57.509881+00
6bfd91a1-0bdb-49bd-9b1a-fa180502c217	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:28:29.543013+00
3cfa96b2-acbe-46a2-959b-5f222e3a7d55	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:28:57.50178+00
1299a68c-9c32-496e-bee8-d8900e441427	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:29:29.614716+00
fe8959f8-1910-427a-839b-11fc33b9269f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:29:57.569982+00
4a6f2c41-d606-4481-b484-0a2763130dcf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:30:28.359721+00
7912d68d-f0e2-41fd-b1f9-d18d4623c84f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:30:57.185112+00
2801ea63-1369-4b95-9800-d7e0e7a546d8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:31:29.393485+00
510dabfe-aad6-4b8e-9a94-9e4f7d30c14a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:31:57.19755+00
3821bd70-ca6c-46f9-8ca8-9817723a6b7b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:32:29.318012+00
6d341485-b1bc-4296-95f5-3c283de332f2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:32:56.224263+00
657e2d53-ba9f-4bbe-ba8a-1b97dd59eaf7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:33:29.581572+00
3ab54159-fdb8-42e5-9fb6-fd05d852f7af	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:33:57.289859+00
8dd4643a-69f3-4ac6-8724-ad5cfd0f9b67	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:34:29.550376+00
ac515e20-5cca-436c-b870-3f4474a1b1a3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:34:57.294217+00
706018cb-74e4-4d24-9a3d-bf47f0212578	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:35:29.540343+00
eff853cb-ade4-48d1-8fa4-1fc9b48a35fd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:35:58.256459+00
ab3a090a-e806-4ad2-9f9c-a0207fc15453	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:36:29.867237+00
91bc3b91-71c6-4a20-bb3a-cde05c51d62b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:36:57.537642+00
1be02547-1b06-438f-b28d-7d5410357ad2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:37:29.539216+00
d50dd8bc-fdcd-4db8-9c5b-ced1e78e361f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:37:57.581853+00
c8d04255-6782-462d-bd34-e90e3fd95baf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:38:29.481495+00
6fc2dd3c-16c5-4c0d-9c28-129a3651ffe8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:38:57.613444+00
36364a8e-2d0a-4141-b407-a0f71a0fcd04	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:39:29.76661+00
1a440d00-dea6-47da-acee-5871c5f36317	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:39:57.412594+00
c39b0824-947d-49ea-a074-b0c4d999f73b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:40:30.606342+00
88ed0a16-5124-4968-9b7f-caa5e1ba36d4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:41:14.372361+00
588d4237-3f4d-43ac-860b-8c7894e9088c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:41:43.176374+00
b169815f-08de-4075-a2a9-97ca6ab6a97c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:42:14.319855+00
bf13464a-f859-41c8-ac7b-6fcc395e09cb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:42:41.638453+00
3a6af85a-c69f-4112-8379-5531b7559ab9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:43:14.381042+00
44fc4f73-8a39-40ab-a00f-4d0a03974fe5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:43:42.753766+00
5ca16a17-af97-4c59-8e0f-d2d8e35d9281	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:44:14.167495+00
8787a111-0bff-4434-9767-61380e5321e3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:44:42.745658+00
61a8c591-236d-490a-ab2f-23c2c2268c14	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:45:14.235753+00
ba7ff76f-0bda-4b18-b4d4-aaac457bf36f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:45:42.722924+00
226933bd-13ab-405b-9be4-a83736b8b3ba	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:46:16.34813+00
3d40274b-bf44-4882-b6d1-353cd284cce3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:46:58.29797+00
53710607-d871-4a0f-b745-8dd66882ae89	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:47:29.778147+00
d2388bff-e075-47ff-a7f9-a0bec8af0db1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:47:57.679605+00
9e511103-08fa-497f-b85d-4a2aadae8f38	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:48:29.99313+00
79b61ad2-70e5-420e-b9f4-3f0af14d9b4c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:48:57.881128+00
39e545b3-ce9e-4b78-a624-a4bf3256b79b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:49:29.96173+00
0042fa6a-3716-49ba-90e5-50e0b5a173fb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:49:58.227789+00
9ab04a79-ca07-4a98-9bdd-ac7f4ba0cb3c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:50:29.862249+00
2af0f258-2b38-4bde-b36c-7bf7a6dfa52f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:50:57.996511+00
e6daa288-2b99-40e7-a78b-6523e4f3110f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:51:29.968766+00
7c7109a0-8655-4794-8f2b-90a2efd203f0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:51:57.918442+00
30dc14da-6fd0-4271-81d2-ea578eb9dc96	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:52:30.772666+00
7cc4989d-003a-47b4-9492-db7ed3ee5710	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:53:14.736091+00
64ce0f4b-235c-4fe2-9951-ae223893d5ea	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:53:42.955934+00
fc7acb40-aa43-499c-8adf-eaa897ddc6b8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:54:14.624834+00
094187e8-371c-4832-a00a-afc6872f54b2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:54:42.80413+00
9af5deac-cefd-455f-8f1d-df351dfcc133	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:55:14.654022+00
ff7ab7f4-4a92-4b37-ba96-a39357c76329	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:55:42.991453+00
e4b051a3-41d8-422f-9299-e8fd8636901b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:56:14.740191+00
9c584688-25c2-403f-bfad-f048e6aca054	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:56:43.915941+00
c2c725df-341e-4bbd-be4e-fbc18884c56b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:57:17.044742+00
ea14a69d-5606-4438-8d7b-7fd260c5984c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:57:58.556946+00
3e1ad61d-f82a-4f80-9734-9f6f72ac38d5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:58:30.315148+00
7c7fd73f-04cf-466e-8791-7972041fae70	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:58:58.146731+00
b00375f1-96d0-4c5a-a63a-4a22efb3cdcb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:59:30.175789+00
08b78fa1-6a0e-4bf9-a973-204d000443a6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 14:59:58.155648+00
83bb0f1a-1a2a-4029-a09a-b6c2b55f4c3d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:00:29.260303+00
9903117e-4abd-416d-ad97-f6b9f619624a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:01:08.279249+00
8d40767d-937c-4a56-b901-b35b55f98e9c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:01:43.268848+00
ba1d2302-93e4-42dd-aafa-6fa314b8f4db	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:02:13.693359+00
ef449084-1cd1-481e-852c-2df7c47b0f0f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:02:42.208237+00
0af85b1d-84f9-4b77-aa2f-114e31b7c629	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:03:14.001129+00
01658503-fd5e-4386-8018-758f525f1c96	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:03:42.163271+00
84db02f7-9812-4c46-b027-8e288f9b91b2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:04:13.826433+00
10ee93b1-9d60-442f-a9f7-31d4dfc63bd7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:04:42.294239+00
ac624e51-88a0-4e78-a357-f34f8b3665a0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:05:13.978654+00
8903cff8-b697-4f04-bcdf-4124517ff062	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:05:42.331864+00
a22c698f-56d7-4b83-8b90-866a9c7cfaf4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:06:14.056491+00
190dda9c-8f5f-4304-9a97-f5dfe57374a6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:06:41.310412+00
c50e1ccf-17b8-4647-96d2-3f76c513d171	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:07:16.196307+00
3a775565-8a01-4a04-aa0d-e2942c784232	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:07:57.920248+00
933ccd6a-8fcb-4eb5-9985-bcd793779adf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:08:29.373739+00
fa5c284e-68f8-483a-b45f-7b310378b178	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:08:58.251448+00
4b12b2da-0c14-420f-961e-60675da90352	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:09:29.401774+00
6b6e788c-1863-475a-86fa-47447325c4fe	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:09:57.508709+00
3b041ecb-b3ec-4c7e-9a7c-74d89ab6c43a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:10:29.56925+00
d10e44dc-3cfc-414f-9c2b-787b6adb921a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:10:58.505664+00
a84c7ac2-a528-49b4-9c62-7b7a52128e5f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:11:29.577793+00
bbf047f0-1af5-4542-a373-16f667306732	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:11:57.618101+00
1fc239ae-43f2-4f0b-9f19-6438e2d06835	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:12:29.534948+00
50262b18-877d-4b8b-9220-3c98245555e3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:12:57.442095+00
530ff679-4067-423f-a540-6f00a3c2b523	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:13:29.569988+00
d220137d-3adc-4891-a5b6-396251427699	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:13:57.613897+00
58cae80e-5e03-4f7e-a202-369fc348094d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:14:29.539627+00
e57a84da-ce0a-4dea-badb-5fba281345bd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:14:57.458585+00
22d40716-b100-4a59-8e15-5ca3f92aad27	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:15:29.580293+00
bf482015-2f55-415b-aa81-f51192ae92ec	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:15:56.854107+00
573427cb-6e7b-4b33-a4db-a4293c63fc28	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:16:28.79162+00
6d083168-3958-4fb4-a838-475580238a32	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:16:58.895327+00
7de99adb-2334-4461-940a-dbd753fbe219	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:17:31.801065+00
d7372d7e-0d60-4a9c-aa1a-f007b1d09267	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:18:17.013275+00
96e0a567-508c-47cf-bea9-3cfda868dce5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:18:58.092359+00
fa3158f5-cdd2-441b-b776-f3cd9635f92c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:19:30.181286+00
16f394a3-9a89-4519-99b5-d3e6cf375008	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:19:57.085199+00
d28b7af5-9054-48d4-8583-b61644322d5a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:20:29.993978+00
f25277f1-f70f-4423-a8d4-1e764bebd37e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:20:59.089361+00
a18e3702-020d-4e15-8fa9-9f8c3c00ff7c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:21:31.043412+00
fb453305-df02-4681-bd4d-0520261aaa11	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:22:14.840848+00
cad39a6a-43c4-425c-aaa0-209f9c25d789	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:22:41.89525+00
11dde838-dfd0-47ba-bc7d-07bade577fa9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:23:14.931597+00
8726c041-c426-4b91-9054-c693173002a3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:23:44.499332+00
d604c5fa-0aec-43db-a2e3-fa42e0642730	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:24:14.871122+00
540d6e1a-e8bc-475b-9519-5102820fe149	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:24:57.228153+00
bd4019f4-cc3a-4736-a91b-2cfafd439dc1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:25:29.76467+00
36101762-d6c6-4471-8425-46c2ed5a9bb8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:25:57.222125+00
35eed981-d9c9-4eb7-b698-32d030cda600	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:26:29.351018+00
de05a537-70a3-4d9a-ba7c-8ebd8c89a681	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:26:57.2518+00
e5bad421-f2dc-435c-93fe-bf92b03df939	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:27:28.621682+00
2f2164a4-e0d9-460b-ab26-2ab22e9212d2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:27:59.282953+00
5884cc73-d7c8-4e5d-9b25-be596211fd8e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:28:29.59205+00
85ad3fd3-e2d4-4d71-a440-c6d0d2d65ae5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:28:57.127304+00
4d069bba-1ef8-4510-9ce9-a7c7307ba929	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:29:29.221172+00
1cb2ce2c-1147-4c60-939e-c2a96abe1308	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:29:58.343447+00
963860c2-1ee0-4120-8f8c-c7ea19abfe56	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:30:29.239931+00
fd4c634d-25bc-4709-881d-184ca71e5e72	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:30:57.200853+00
ae67104f-e2db-489a-a44e-818dfd21001f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:31:29.548065+00
fbe0673d-b122-484b-953e-02713d70428e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:31:57.418802+00
e7f22727-172d-4d07-b754-c5b74c7b0e6d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:32:29.270963+00
513ebfe9-d582-4028-b4f6-26e2ff515a43	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:32:57.440242+00
e1567401-a0c3-471a-8cfe-f0b930f3ce20	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:33:38.59549+00
261ee84a-a598-432c-9c55-5120a5d0dbfc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:34:14.360567+00
ec988a44-75f6-4552-a2ee-36861675b38f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:34:42.408488+00
d71fc75d-ae24-493e-a230-d9d2dbf00c5b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:35:14.18064+00
01adf09c-0634-4c2a-ab5f-2b99efce9964	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:35:41.525064+00
9ee66129-095b-442a-8260-5e0fe1c4f055	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:36:14.20568+00
f09583f9-c6aa-49df-a5e1-e0a0402b31a1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:36:42.331103+00
621b73a1-38ae-4c01-bfb6-7b5f190923e9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:37:16.520123+00
8eaa9cd8-9606-4df2-9014-027bd86b0219	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:37:57.616848+00
e8548594-aa97-463a-b4a1-bd3588adaabf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:38:31.615706+00
bc0c39bb-716b-4813-a2fe-fcd779a1e99e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:39:16.820934+00
18a014ef-de46-41c1-abe7-0f185f08f091	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:39:57.619686+00
ffedbe72-8911-4dbd-bbdf-c2e7bf3b825b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:40:29.598658+00
89f06d63-66de-4c5f-99f5-a834a1ad5565	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:40:57.634115+00
76822c97-94b4-4120-9ea0-3a6cc003ce20	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:41:29.598696+00
3bcbbdb8-3b7f-4b7f-9417-ef396d401fc2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:41:57.704556+00
fad0fad5-bb4f-4022-980b-28d04050fb56	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:42:29.65486+00
d77414f4-a513-4780-a923-ae751716731e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:42:57.714779+00
0c7467cd-72ef-42ff-82d8-eb610dafed5e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:43:31.819251+00
c3518f81-64df-48a9-87b2-f6c0ad2eba41	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:44:16.879591+00
90345102-4ef0-4e1e-a284-350686d451c2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:44:58.170839+00
a48576aa-4fc7-44b0-a314-786e26d5db22	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:45:31.329393+00
52cd760b-de69-47c1-b642-b6b641f57906	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:46:16.907494+00
761796c1-effc-45d5-9499-ebbe5bd7fe22	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:46:58.294221+00
d1d6a987-a705-4420-baba-34ad5bfd319c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:47:30.027124+00
7efc505c-1ab7-4a1f-9b61-312c4f119f7a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:47:58.325872+00
3b3c29c2-7e3a-4388-948c-3e66b3e07133	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:48:30.163124+00
e7896bcc-3853-4e31-bfa3-c809f3620e3b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:49:00.258657+00
c654903f-db5a-401f-a24f-faf0e649434d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:49:30.660109+00
50ab3663-29fa-479d-a888-d60cff77d47a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:50:17.08775+00
ea151b4c-4223-4fe2-8340-f6555f5a4c22	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:50:58.164252+00
47ae23c7-3bcd-495d-bc64-3fb307673519	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:51:30.182434+00
ac6bf8cd-7c83-4786-9eeb-2c5bd4f55738	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:51:58.105776+00
b0e7fd05-2970-4c03-933a-6bd7cb1edf1a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:52:30.160045+00
c7cb06fd-f430-4e9c-8b96-86ecd630038e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:52:56.95358+00
2151b9e2-337c-481d-99d1-60b17c1f6aed	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:53:30.426001+00
29fe82ed-2981-4393-8f7b-bbe93ccc4ce3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:53:58.002937+00
3da9bc4d-bbf3-45d2-b393-dee616cd2246	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:54:30.09049+00
67f630e1-0131-47e4-a9b4-af1c7f9e062a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:54:57.979552+00
01fdc501-185a-4a81-9302-47728d86164e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:55:30.174226+00
f34fd2de-b1bf-46b8-826d-04d73adf03f8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:56:13.941506+00
4171df5e-20ed-4f6b-bd4b-9cbe3ae032bc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:56:42.033968+00
90b4e4b4-55bf-4322-8a90-16f091cfd42e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:57:13.937958+00
c3507dd7-2268-44c1-854c-900e64048044	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:57:42.309621+00
d57b50bd-6c8c-4160-b10e-6011d1ad7091	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:58:13.807722+00
e3b3ac75-e19c-4be2-a09f-e35d80bf1876	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:58:42.067295+00
8e4f7154-c9f3-4d9a-9d60-efb07064f4d7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:59:16.112243+00
c3fea37d-35f8-48da-b4ba-276d46f430eb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 15:59:57.924129+00
434a2878-30e1-4640-b60b-afa6c6f66222	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:00:29.216907+00
fddc079f-5cb2-47f1-9023-b2494afc92c0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:00:57.35657+00
74517051-c060-4496-b4a5-e5ace3ec088e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:01:29.388286+00
0f3097cb-bb69-4305-8406-f2527ba5a4ba	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:01:57.254012+00
b235d572-0d14-429b-96dd-244c4ebed9c9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:02:29.348982+00
da2f0c6c-3ae0-4268-af54-742b3acdff5f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:03:08.683228+00
30554c10-cbfd-42c5-8319-2e1016effb14	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:03:51.877806+00
63b84b3b-be92-4d94-ae33-af709345ebb1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:04:29.537249+00
8ca27a8c-a828-4702-bde6-7aa447ffccf6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:04:57.462147+00
9d66572c-15c7-4536-8b59-e5f151d790f6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:05:29.407493+00
f333fb78-171d-490c-b631-0fd7b40dc438	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:05:57.328261+00
9dad88c5-5e1a-4602-8a69-31a394098ea9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:06:29.372697+00
08acb1fd-feda-4fd4-9034-194cb272d2cd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:06:57.509216+00
1325b7d2-dc5e-4c4a-8745-f03b893877c9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:07:30.442685+00
089a3387-8888-4489-b645-ce3bb7eaf162	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:08:14.210462+00
b3ad3933-631f-4758-ac1b-fa93d511e269	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:08:42.34088+00
1bba79b1-877c-4594-8999-be5b4718230f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:09:14.208532+00
ba80ea74-8c6d-4717-ba8c-e9abf6244619	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:09:44.479944+00
29bcc8ca-78bf-460f-a300-2591c80fde24	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:10:16.471803+00
626f0cee-b448-460a-99d5-265df145555e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:10:57.735347+00
7d23ee46-461a-4e9a-afaf-95e43c612e01	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:11:29.582739+00
8f28cf79-b6ea-4cfd-9723-78e121753567	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:11:57.62441+00
bdd7699e-581b-466e-9af8-1c1ddb86f24f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:12:29.295342+00
3cba60d1-710f-4c6f-a409-3b1cb0012652	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:12:58.434117+00
45a86f60-b47a-4e1a-9f1a-6408fc3bd3fe	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:13:29.586891+00
1dab8269-fbac-4a13-9122-ad8e13fa183c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:13:57.49015+00
f6b8dccf-054a-4a3d-a47d-49f61d9ca9d1	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:14:29.724891+00
b63640e2-7a87-45c2-b2c1-5f130663ff73	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:14:57.85713+00
88c89284-acfd-45f9-8e20-d19e3edc2d18	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:15:29.580526+00
9ce8e3e9-0845-4b76-8a1e-3029bc760f74	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:15:57.698656+00
c6390866-b72b-4169-9250-f4fac87b53d9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:16:29.545001+00
f7869f62-943f-45ae-bd21-20ce6976db42	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:16:58.270449+00
178ca49a-4902-4080-ad3c-e520fdf890bc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:17:29.590134+00
99aaed01-845f-4574-a4c2-35a56379bb6b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:17:57.534618+00
f1be62eb-5162-4cc9-87cb-701439e93614	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:18:28.665369+00
a25edc3b-fe58-4717-9a09-3a4229273f02	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:18:57.753899+00
77b9fe5c-334a-4423-a227-5d8cfcb17634	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:19:29.7726+00
5009246d-b6dc-4318-85f9-ca1db22bee12	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:19:59.616793+00
aedb8aa8-e353-44e8-8c8b-7450532cd044	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:20:30.097852+00
1c94cd0c-18ec-4f73-b56a-491819573469	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:20:57.76139+00
f1086a03-9db2-4220-999d-8e5a96fd15bf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:21:29.773303+00
b04b1779-73d5-427c-88a2-1a760788d447	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:21:58.888799+00
0e94dec0-430b-40d5-b99a-1e5450a0c939	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:22:29.498164+00
04f78bbd-2c0b-4023-a8fc-e643e26e7fb6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:22:57.589527+00
d4c9abc5-bbb2-4649-a613-c479d8ffcbed	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:23:29.767062+00
d53d0e17-d6d8-4fa7-b746-e2e774bd85fa	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:23:56.843325+00
87c048b7-5544-4689-b8b2-9754dadf4999	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:24:29.731326+00
6e7c1ff8-f088-40cb-9a9c-86ee9ca43844	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:24:57.884446+00
f3164679-f317-4869-9471-4f1eee044ad4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:25:29.79913+00
fc1f92f9-58fd-4ccb-8ade-a48b9304dd24	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:25:57.883301+00
3eababe3-2fe0-4577-a356-92d54a5c8445	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:26:29.771016+00
015da1de-8434-4279-81a1-010bd3ec2382	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:26:57.857749+00
827b09e3-2437-482f-b39a-99fa0d826c99	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:27:29.788692+00
e4c1e1d3-9393-4982-a436-bcd339fca22a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:27:57.920767+00
5a2a24d6-9427-4438-91de-3fa55ff1534e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:28:29.80011+00
06282c0e-fe25-4872-92ec-ee1c2fbbd68d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:28:57.7435+00
656bda2e-5398-4fef-881c-0961c5d1d69c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:29:29.616056+00
19e53c06-95aa-40d0-95b9-2846928836df	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:29:57.955757+00
629064b9-32d7-415d-b62c-aa59541c0acd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:30:31.695813+00
70421dca-fc6f-4401-a2aa-a1fe3b548808	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:31:16.982755+00
f0772988-c564-4d95-83b7-064fb827b087	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:31:58.000676+00
34a4f80e-b514-4997-8a83-50b7e5e16d8a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:32:39.805615+00
cc09c35e-08f1-4f0c-9d2d-4c39133b5394	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:33:14.689239+00
cbbf35d3-0ffc-4277-b425-8376ff6cc7f8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:33:42.978621+00
0a404a19-31b6-46b3-bcc0-18658576f75b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:34:14.665369+00
51c7568f-b7fa-4dc9-a8f1-1d358c9e81f3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:34:42.976078+00
fd863555-c9ee-4700-9596-b0cc40f38ae3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:35:14.895672+00
18b3e1cb-2793-4f4a-a217-4c4e89e3e01b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:35:42.960812+00
2fb490a5-87e4-4cec-9385-1f3a3e72e6c6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:36:14.734462+00
2db309b5-7945-42e9-bc9c-980a60a90fd4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:36:42.911634+00
30772f0f-4a0f-43f9-b297-78f107bf0ccf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:37:14.755574+00
9fcae1fe-7cab-4703-a0e9-afd7d7bd86d9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:37:42.932922+00
120e9cfc-b358-4138-982b-401d8d767f45	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:38:14.804842+00
6e356aa5-ae07-4746-9008-211eeaa9c1e6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:38:42.887634+00
67db729a-3ef7-477d-9843-21efe13cfdf7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:39:14.856912+00
e04e5f4c-b735-4786-a5aa-6de5be7c2e54	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:39:43.14867+00
86d71d41-f0ee-4d10-96ec-8dc6d5325a1a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:40:14.62604+00
25254f5d-8320-4ad0-969c-b71c31a57b52	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:40:43.873634+00
c3a8f44e-0cd6-4c60-859c-a5d0e248d246	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:41:16.244574+00
72d08b77-74d8-441f-b9cb-d1ab66428acf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:41:57.225826+00
e2310863-1bad-4ff4-9650-e4650e850a47	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:42:29.21363+00
67d98904-9cea-424f-a480-63dc68c10267	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:42:57.23461+00
74dbda5f-6ddd-46d9-a298-50994f77c7fb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:43:29.228953+00
1b1cd029-2b18-4a0b-93df-7ca1b499c06a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:43:57.180786+00
0b29c614-f125-4cb7-ad42-d765ac3d4bf7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:44:29.290688+00
b4ac16a0-0808-4fc8-80fe-7bebcf9bc3f2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:44:57.329555+00
44b2dda8-532f-431f-9639-cfabc683cf71	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:45:29.367509+00
6d712ccf-2a59-4389-9c56-a370088f1322	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:45:57.798996+00
781c7dd2-bb22-4659-8df3-86fe24ec7e28	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:46:29.260837+00
c19ac1ca-c9a9-455e-8c5b-81d69c1e71ff	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:46:57.351548+00
753ba407-7ab9-4639-9859-53ae23a77d3c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:47:29.375845+00
fe72606d-0e19-4d40-a4c8-a65179de6f8a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:48:13.248508+00
9c7f05ef-c7b8-4b8f-b4f6-12ef19a96f66	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:48:42.395929+00
047c5563-93f5-494e-b6e0-c8dcdab55042	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:49:13.921222+00
83840fbc-62e8-4a08-91f6-bfbbf49894e3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:49:42.855305+00
dbf0cd18-a06d-4e44-852d-4006e047c8b0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:50:14.096464+00
835445b5-d406-4e53-968a-e19ee24ccc64	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:50:42.413476+00
496f066c-bd36-4a8f-822b-57893eccc26f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:51:19.00182+00
1c29bffb-5426-4e83-9e09-a9a9ea3062aa	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:51:58.022638+00
5cb79b30-a16f-4ad2-b6ba-112e3285c795	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:52:57.472338+00
e4ad7af0-cc88-480c-b46c-95e51db47074	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:53:29.295533+00
7d59ccb6-1b78-4a9f-81c2-b017bfefad4d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:53:57.169146+00
d6a8f11f-7211-4131-9291-a8f1546722cc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:54:29.337944+00
75e1d9b2-7e83-4718-8927-367ff4a27b09	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:54:57.457409+00
8945529c-48f3-444f-8265-bb75d045c7de	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:55:29.648899+00
76ef7152-55fa-45be-9726-33710e2bc103	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:55:57.530725+00
e7f388fa-685c-4302-b72a-37b03570d19a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:56:29.458816+00
79f4a631-fef6-4860-8303-1e6fca57d591	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:56:57.538528+00
1bd119fb-d429-4a93-817e-45af921b92a3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:57:29.415865+00
d94d96e4-a38d-48a6-8204-ba09147d9e5a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:57:58.545153+00
9688306f-d14b-4c50-b0dc-a9ea0519f54b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:58:29.271241+00
5ef6c0b4-3f36-46be-90dd-39a367bfc53b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:58:56.58026+00
a071212e-0abd-4dea-a79c-9ac116f433da	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 16:59:31.025259+00
5bb95b63-3260-4237-aec3-3858e03da10f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:00:13.228718+00
b94ea56e-7f7e-4c78-9057-dba4aa96888c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:00:42.632062+00
a7ef328c-53c9-4bfa-91ca-d644ef71f927	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:01:16.606946+00
6398cbd3-02d2-4591-b087-b6370654e81c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:01:59.616038+00
ffed2cc3-09f9-44df-b95f-5b4e3f94156c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:02:29.98077+00
039dbc1d-969b-45eb-8569-076a41638200	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:03:29.838844+00
f2407ef1-9fec-4436-825b-4f454a9d57e7	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:03:57.777727+00
9d56bab0-ce78-48c6-9060-a7620e5cebcd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:04:29.63242+00
44fae28b-1db9-41eb-bdc7-1bc2e0df6f87	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:04:57.841374+00
54d72a8d-7f73-45b8-bbca-8c71b0a11633	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:05:29.692431+00
65328bf2-e00e-4ef8-8675-e10e1ad6e92c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:05:59.509937+00
ede5ac52-9488-4968-80a1-24a272ef024a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:06:30.713111+00
a416ea3c-cfce-4829-8a62-d897366de616	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:07:29.801619+00
9c652f8d-9302-471b-ac04-d0c6a6bc83ed	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:07:58.471525+00
f5b5bc11-cabe-46cf-8fc2-8c7d5ef29969	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:08:40.124145+00
d4c2950d-5d64-4eb7-b490-a5e2750aa493	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:09:13.382418+00
5ce27160-3f78-4a27-802a-d0bcf018756f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:09:52.844823+00
c3cd1953-3e41-4df6-b97d-db06f13bde22	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:10:29.678216+00
7eca3109-e1fa-4588-b364-406e5ec7dafa	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:10:57.602184+00
85ced1b4-6b9e-425a-b2cf-02b207a296a5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:11:29.435913+00
5d8276ce-9ce5-4ba8-b5b3-3bdbb89d53ca	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:11:57.7954+00
47d260b0-fa29-448c-b580-2a48e744065f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:12:31.861656+00
3e8f0568-6778-4a56-a16e-3062b333d469	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:13:17.053395+00
e1a9469d-f68d-4b69-83cf-e9562579ef57	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:14:09.436979+00
bce669da-7d8e-4ae2-9b8b-fd12a7103655	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:14:42.760904+00
897bc68f-70f0-42b9-a481-408c5c0e2676	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:15:16.960662+00
5de86b5f-0532-45c1-bf16-f9b5188c3578	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:15:57.69588+00
edb39299-84b5-4765-8f15-04f0ad5112bc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:16:29.547762+00
134fa886-c2da-4931-886e-8e7023c7bc86	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:16:58.526275+00
6cc10120-989b-4012-b37f-b85419f96dca	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:17:39.404468+00
ac834c7f-d27d-4ec4-aabb-5640e333b06e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:18:14.615014+00
0e521eac-a5d5-489e-822f-18c17b4aaca4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:18:42.623501+00
8f2fdaf9-ffaa-4756-a47a-bce9ddb5d9e4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:19:14.616761+00
e14b01b7-d29f-4411-8784-6065d78c3421	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:19:42.501832+00
9a23186a-b471-4dfc-a720-010175bd2af3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:20:14.234305+00
11ada632-90d2-40d9-a751-1e5cacc6de9b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:20:42.643701+00
730bf96d-7063-4e9f-9f71-ed480e7777f9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:21:13.649007+00
2cdd0d77-4cba-4d52-8b0f-345146b866ae	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:21:42.599796+00
d2dab767-3daa-4726-a939-af440c20b958	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:22:16.858058+00
ace99e7e-bb5b-4917-b523-41f7187cfdd5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:22:59.914234+00
e6e29610-392b-4aba-8f54-4fa38855d978	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:23:32.606231+00
c1fbd8dd-4583-45a9-95e9-8651b1fa729d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:24:14.792377+00
e09cb2a5-f09a-4134-9dc1-70c78d989a5c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:24:44.251218+00
8dbeadc8-d018-4910-907e-78550f0a38a3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:25:14.950957+00
0c33a027-002e-4311-b921-33c9f283762f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:26:17.13569+00
c909e45d-8c61-473b-9fda-e1a286af8af3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:27:10.215669+00
650f9c5a-4459-452f-b258-876a8089f249	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:27:42.236958+00
98fa8d48-6fd9-4d65-9a31-93b2b72cf72d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:28:17.822386+00
cffa9237-28af-40cc-ba5d-fd5b46abc9aa	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:28:59.274377+00
2f103bb6-334c-479f-a1ca-f22f807b83e2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:29:29.972098+00
5eb25a1b-b271-441d-8abf-c87ee448044b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:30:14.548667+00
4259571f-c16e-46cd-8ed6-259ede6147ac	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:30:43.317626+00
c3a3c2de-9dac-41ac-9711-38338505d13c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:31:16.210347+00
c28fc351-a66b-49fe-8fd4-1707d997a08f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:31:57.836057+00
4825960c-318c-434f-9eed-7a9ff8445467	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:32:29.186856+00
20bd8b38-90ea-46f8-84cc-1d2426e76d95	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:33:11.638377+00
a7b66f8d-f793-40af-b855-f87d9c05c305	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:33:42.686844+00
23f2396a-e3f1-4ba6-a659-605756b7ab80	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:34:17.410899+00
92053054-25b5-4cec-a5b2-75bc2f965867	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:35:08.549231+00
ededdfb8-880b-41e9-8358-a813bfcc76cf	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:35:42.735714+00
5deed5f0-544d-48fb-926d-8dfa95596c4b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:36:16.737902+00
5839a835-492b-4ce1-b4b3-e02b7a65865a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:36:57.990883+00
977abee7-fb8b-45f6-9fc5-6d0d04069d4a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:37:29.853321+00
29e7904d-6e87-4d8f-bb48-db394597202f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:37:58.628529+00
4d4dbe2f-0051-4774-b223-c1c9d4326f96	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:38:30.171601+00
c0d41d78-1e2e-4cee-99ba-47ecdfb11add	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:39:14.318358+00
1aae5ffb-9a8f-45bb-ac39-97173ed3d06e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:39:52.303406+00
323ab428-6747-4be6-86d2-bf24fb895279	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:40:40.017723+00
a9e5c052-b594-401e-be36-5c75440084f6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:41:14.333157+00
5fa6f756-611e-4089-9438-8fab842292dd	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:41:43.041113+00
84755545-f007-4a0d-bb3b-74bf87a147d4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:42:24.351961+00
d633295e-63e0-4c40-95bf-bc2a84bc53fb	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:42:58.203755+00
ac981684-17d3-41e8-b925-733f1faeef46	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:43:33.545004+00
75484747-63dd-4c04-bd9a-75b364f9132c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:45:09.669245+00
3f5e778d-2e2e-4096-a8e3-f052f642b6a4	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:45:44.885925+00
3200cf81-9db9-4f2a-a639-c3767c16100a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:46:17.132291+00
39b32733-e9a5-4eb9-8816-f0bd2f1cab6e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:46:59.108666+00
f6874199-00ef-45fb-8fe7-18c438b66389	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:47:32.430972+00
6d739ebd-d73f-47c9-914d-e08a6a5d2b65	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:48:16.714449+00
9a8c2e91-eca8-4d99-88e5-da4ccda8eace	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:48:59.036742+00
7cb1fc0b-9820-42e1-a98b-31a94f406ab9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:49:29.971943+00
d1af9e65-443f-4fbc-9689-2a519d87395f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:50:11.447049+00
ef3b9aff-9728-488f-b372-157d2c113ee5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:50:53.907071+00
5abd7090-ffd2-425d-ac72-1c780579b93d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:51:41.834968+00
b3bd6569-9401-4849-9e0a-a34aae939779	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:52:17.703895+00
09ee9eec-aa17-4022-bffb-0bfdca4524be	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:52:58.550244+00
eead013f-ca92-4a9d-8457-ecd6a20a3d2d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:53:30.925257+00
11731fa8-3718-46f9-abe5-30c1d69a024b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:54:31.749755+00
adea0d95-269f-4fc3-8346-151e67e74a99	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:55:18.341535+00
d5ebc489-f39f-45f1-832d-4b0e2698f1c2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	provisioned	Config imported	2026-07-31 17:55:31.069328+00
aa449ff9-a66c-4ae1-8ca7-6c1447e04278	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:55:58.243149+00
9a941222-cc88-40a5-bae6-60de2e5092ba	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:56:39.92979+00
a6f2da91-8a31-443b-8eba-d9c023caee50	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:57:15.639265+00
c447ae05-25fc-4fb4-88cc-4bb80f5641ae	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:57:42.94222+00
a11a4549-e539-4c4d-ac01-ad50bb4f1df0	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:58:17.555089+00
bef3a908-245b-46d3-bbc7-4df3fcf0df66	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:58:58.225045+00
c54161a1-79fe-4bc6-9fcf-869313e23b6e	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 17:59:40.253133+00
e48a8c41-a905-443f-9326-f2d4b61a9e5d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:00:25.040801+00
b038f398-d11c-481c-9d07-7c51b3f9fea8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	provisioned	Config imported	2026-07-31 18:00:33.399783+00
a4c7e3ba-ed4b-4daf-842e-e7e8bca4a08d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:01:11.960177+00
9664c83d-239f-4094-ac4e-51bbcd426aed	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:01:52.205851+00
d2081168-25ce-4df6-a632-307433cfb5b6	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:02:31.792953+00
adf5d24d-4dd8-4a52-aa9b-4bf68720bab2	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:03:17.903055+00
21ee41c0-8322-4198-8533-02cb8b7c1322	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:03:56.997423+00
c800ca0b-36ca-4af3-a270-6b7c84dc78f3	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:04:43.212668+00
b9a5ed8b-5f02-42ad-af3b-6f2ff3634a1b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:05:24.679673+00
eac8a5d6-cebb-476f-b756-3c9a4fdde71d	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:05:58.793709+00
df5962f1-ae1b-4e64-99ee-e27a4a77ea04	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:06:31.944315+00
559fc99e-0c52-4014-8d3c-2e5b6016e109	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:07:17.956506+00
b8e6a0ef-d9df-4dfd-a978-130c7d6f8640	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:07:59.096832+00
babeef8f-f37e-4d22-ad95-7455c14a43f5	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:09:00.765953+00
83d715b4-e062-4e91-b1cb-6d54b1a7c2be	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:09:54.949071+00
54dd70ed-c7b7-4ee8-b6ae-2e99df4c03e9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:10:32.618017+00
12f81fc3-0ed7-4325-80d7-4e34b6c9f77a	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:11:24.04327+00
c9c6ca52-eeb9-483e-acd9-443e6062ece8	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:12:03.070924+00
c7fee80a-5cd0-497a-a045-cbca6386ecfa	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:12:46.370047+00
11665cc8-4233-4cdd-9e58-4e60722a861c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:13:29.506711+00
5edcea7d-7a65-4d8f-beaa-b40ef89f0f4b	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:14:09.002725+00
9a68db23-a9bd-4d29-a6f4-416ee36d8557	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:14:46.173696+00
af207d27-ba62-46f1-843d-8b01118952fc	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:15:43.402745+00
55a80e5c-1eb1-49cc-b808-ac6586c66319	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:16:25.423766+00
a3f18af2-22e7-47b4-86b9-150d6c416008	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:16:57.586247+00
1182318f-e52a-4d84-934c-6f8eb0e49e57	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:17:40.930584+00
3d9247f7-3e47-4864-bc74-e45d3ae6529c	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:18:26.177786+00
e0ccfc00-2319-42c1-98cc-ccccf0946da9	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:18:58.727679+00
58b0a75a-04c3-4de2-9f6c-3040cd7bfa41	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:19:41.639005+00
1c04f4f0-343a-4b7b-a310-69c7fa933023	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:20:24.82445+00
8536bbe6-4e26-47bc-a164-0a646f453d3f	c9ef146c-52cc-4c59-81e0-b97414e528a5	98d7ba07-2dd2-42d0-819e-e438ea390565	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-31 18:21:02.755511+00
\.


--
-- Data for Name: nas_wan_links; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_wan_links (id, nas_id, "position", name, interface, gateway, ping_target, role, lb_weight, enabled, current_status, created_at, resolved_ip, resolved_gateway, last_checked_at, last_rtt, is_active, internet_ok, in_load_balance, is_failover, failover_priority, last_latency_ms, last_jitter_ms, last_loss_pct, quality_state, consec_degraded, consec_good, quality_parked, probe_verdict, probe_stage, dns_ms, connect_ms, fetch_ms, throughput_kbps, last_fetch_at, consec_fetch_fail, sample_history, consec_slow, bytes_carried, bytes_since, last_tx_bytes, last_rx_bytes, bytes_month_start, in_pool, last_mbps, tp_checked_at) FROM stdin;
2756dd69-476c-4ad3-ac61-e0fe4ea57a4e	c9ef146c-52cc-4c59-81e0-b97414e528a5	2	Link 2	ether1	\N	8.8.8.8	failover_backup	50	t	standby	2026-07-31 10:54:28.200256+00	192.168.8.6/24	192.168.8.1	2026-07-31 18:20:59.706004+00	38ms506us	f	t	f	t	2	\N	\N	\N	good	0	0	f	good	complete	\N	\N	2194	\N	2026-07-31 18:20:58.891423+00	0		0	11249152	2026-07-31 10:54:28.200256+00	3151140	8863603	\N	t	\N	\N
6606155f-5888-4c81-8955-e71c5aa541c4	c9ef146c-52cc-4c59-81e0-b97414e528a5	1	Link 1	ether2	\N	8.8.8.8	failover_primary	50	t	online	2026-07-31 10:54:28.197625+00	172.31.3.100/32	rl-wan-pppoe	2026-07-31 18:20:59.704456+00	9ms983us	t	t	f	t	1	14.657	6.3	0	good	2	4	f	good	complete	\N	\N	1257	\N	2026-07-31 18:20:45.685908+00	0	0000010000	0	921331485	2026-07-31 10:54:28.197625+00	200654664	723422248	\N	t	\N	2026-07-31 18:18:25.052145+00
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
1f18a410-aaad-4cbe-9265-5e9d9d6d7900	\N	\N	info	New ISP Registered	Rumalink has registered on the platform (both plan)	f	\N	2026-07-31 10:40:55.890746+00
b511e2f0-b23f-4a14-ba6c-94490aaf93f3	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	MikroTik Connected	"DandoraPhase3" checked in. Run the import command to apply config.	f	/isp/dashboard.html	2026-07-31 10:52:15.346239+00
bed2501f-3c1e-4376-a4b1-ec70b036e41d	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	MikroTik Configured	"DandoraPhase3" pulled and imported its config.	f	/isp/dashboard.html	2026-07-31 10:52:27.747794+00
1347bbb5-f02e-4572-b60d-1b8be3b0b32c	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 11:12:00.583658+00
e039f6ae-0dad-4c51-a93b-c9304272c342	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 11:16:00.724153+00
2df64c85-7f91-4f67-95ca-f7071b131c44	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 12:57:00.602224+00
7b4be9db-108a-4f91-92bf-f342eda4c57b	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 17:10:00.400316+00
8ed1b341-587f-4885-9b65-52329e127841	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 17:28:00.945593+00
537fa173-71d6-45d9-8016-9993c40f7b8d	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 17:33:00.118722+00
dd596ada-1f85-436a-b249-710718e8f909	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-31 17:35:00.182964+00
cebd90bc-d924-45a3-8904-82b0cfecda96	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	MikroTik Configured	"DandoraPhase3" pulled and imported its config.	f	/isp/dashboard.html	2026-07-31 17:55:31.067554+00
e3dce03f-1c65-40e2-b493-77c845a95e9c	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	success	MikroTik Configured	"DandoraPhase3" pulled and imported its config.	f	/isp/dashboard.html	2026-07-31 18:00:33.399657+00
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
592ff04d-28cf-42d5-8711-e1d2fef380fa	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254740258495	0.15	0.0300	5.00	failed	Request failed with status code 400	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C"}	\N	2026-07-31 11:05:03.00333+00	2026-07-31 11:05:03.00333+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
97790357-c1bf-41f5-bc2d-7c43a4fca3c1	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254740258495	0.15	0.0300	5.00	failed	Bad Request - Invalid BusinessShortCode	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C"}	\N	2026-07-31 11:08:09.389029+00	2026-07-31 11:08:09.389029+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
de349b36-67b3-476c-98be-874ddb1434a4	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254740258495	0.15	0.0300	5.00	failed	Bad Request - Invalid BusinessShortCode	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C"}	\N	2026-07-31 11:09:07.092981+00	2026-07-31 11:09:07.092981+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
168347ab-f86f-4347-b73f-dc6307fe7df3	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV13135UC	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "R3", "rl_purchase_sms": "sent"}	2026-07-31 17:09:48.019311+00	2026-07-31 17:09:24.608961+00	2026-07-31 17:09:24.608961+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 17:10:00.367086+00
e89b3041-b526-4923-8e5a-e6c7c224f35d	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254740258495	0.15	0.0300	5.00	failed	Bad Request - Invalid BusinessShortCode	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C"}	\N	2026-07-31 11:10:17.073234+00	2026-07-31 11:10:17.073234+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9fd74c8d-039a-4835-9d69-6274027d22d0	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV13136DE	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "R3", "rl_purchase_sms": "sent"}	2026-07-31 17:27:41.129876+00	2026-07-31 17:27:26.895347+00	2026-07-31 17:27:26.895347+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 17:28:00.924231+00
e5826f3e-20c7-486b-a7c1-bb9f5fe068b6	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV1311IIM	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "K1", "rl_purchase_sms": "sent"}	2026-07-31 11:11:41.622281+00	2026-07-31 11:11:27.683369+00	2026-07-31 11:11:27.683369+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 11:12:00.55863+00
9c5f1841-386e-40b9-aa86-b48fae5b41de	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV1311EHR	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R2", "rl_purchase_sms": "sent"}	2026-07-31 11:15:11.093358+00	2026-07-31 11:14:52.645723+00	2026-07-31 11:14:52.645723+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 11:16:00.685426+00
c9ffa22c-9e6c-49b8-976d-053bbbb59d0e	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV1311SNA	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R4", "rl_purchase_sms": "sent"}	2026-07-31 12:56:57.774241+00	2026-07-31 12:56:46.107391+00	2026-07-31 12:56:46.107391+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 12:57:00.58811+00
895bc1e3-be4c-44b9-ad5a-067f54bbeeba	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV1313C8D	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "served", "rl_purchase_sms": "sent"}	2026-07-31 17:32:30.245109+00	2026-07-31 17:32:14.636267+00	2026-07-31 17:32:14.636267+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 17:33:00.094376+00
e163ad72-523b-43ba-b804-2268bb538ae5	98d7ba07-2dd2-42d0-819e-e438ea390565	\N	\N	5.00	KES	mpesa	mpesa_stk	UGV1313B05	\N	254740258495	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "served", "rl_purchase_sms": "sent"}	2026-07-31 17:34:50.986237+00	2026-07-31 17:34:27.018707+00	2026-07-31 17:34:27.018707+00	f	\N	\N	\N	254740258495	5.00	\N	\N	\N	\N	\N	2026-07-31 17:35:00.158371+00
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
\.


--
-- Data for Name: radacct; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radacct (radacctid, acctsessionid, acctuniqueid, username, nasipaddress, nasportid, nasporttype, acctstarttime, acctstoptime, acctinterval, acctsessiontime, acctauthentic, connectinfo_start, connectinfo_stop, acctinputoctets, acctoutputoctets, calledstationid, callingstationid, acctterminatecause, servicetype, framedprotocol, framedipaddress, acctstart_delay, acctdelivery_date, realm, acctupdatetime, framedipv6address, framedipv6prefix, framedinterfaceid, delegatedipv6prefix) FROM stdin;
1	8000001e	d5757ac1a7da8db9a166212b87a96044	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-31 12:04:37+00	2026-07-31 12:15:22+00	120	646				8385683	21012362	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.245	\N	2026-07-31 12:04:37.452279+00	\N	2026-07-31 12:15:22+00	\N	\N	\N	\N
2	80000022	cd01a546b83be7ec83ef4f7802d2b21c	R1@98d7ba07	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-31 12:57:01+00	2026-07-31 13:56:58+00	120	3597				3262766	3880689	rl-hotspot	66:87:6A:49:95:DA	Session-Timeout			10.100.0.245	\N	2026-07-31 12:57:01.624278+00	\N	2026-07-31 13:56:58+00	\N	\N	\N	\N
5	80000028	1b62e3c0fd434a5cde47dddae86c8d1a	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-31 18:16:58+00	2026-07-31 18:17:03+00	\N	5				60	260	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.242	\N	2026-07-31 18:16:58.563186+00	\N	2026-07-31 18:17:03+00	\N	\N	\N	\N
3	80000025	4f2243ebb9ac81077a50ae3e5123a37a	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-31 17:21:36+00	2026-07-31 17:25:57+00	120	262				1935756	19951413	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.245	\N	2026-07-31 17:21:36.747382+00	\N	2026-07-31 17:25:57+00	\N	\N	\N	\N
4	80000027	adebc80993ebcce674e52f880966d765	R1@98d7ba07	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-31 17:34:46+00	2026-07-31 18:17:03+00	121	2538				14607850	69266542	rl-hotspot	66:87:6A:49:95:DA	Admin-Reset			10.100.0.245	\N	2026-07-31 17:34:46.665517+00	\N	2026-07-31 18:17:03+00	\N	\N	\N	\N
7	80000029	8764214b21f3eceb3b9652eef25d4d15	R43@98d7ba07	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-31 18:18:06+00	\N	0	120			\N	11767432	28162176	rl-hotspot	66:87:6A:49:95:DA	\N			10.100.0.245	\N	2026-07-31 18:18:06.333827+00	\N	2026-07-31 18:20:06+00	\N	\N	\N	\N
\.


--
-- Data for Name: radcheck; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radcheck (id, username, attribute, op, value) FROM stdin;
19	R3@98d7ba07	Cleartext-Password	:=	35c5c4
24	R4@98d7ba07	Cleartext-Password	:=	a5yay5
25	R5@98d7ba07	Cleartext-Password	:=	9cb8bb
26	R6@98d7ba07	Cleartext-Password	:=	y329a9
27	R7@98d7ba07	Cleartext-Password	:=	35f536
28	R8@98d7ba07	Cleartext-Password	:=	7x9546
29	R9@98d7ba07	Cleartext-Password	:=	2y64y7
30	R10@98d7ba07	Cleartext-Password	:=	xyy556
31	R11@98d7ba07	Cleartext-Password	:=	y23x7e
32	R12@98d7ba07	Cleartext-Password	:=	53deac
33	R13@98d7ba07	Cleartext-Password	:=	a85fea
34	R14@98d7ba07	Cleartext-Password	:=	8adfy3
35	R15@98d7ba07	Cleartext-Password	:=	4c9a5c
36	R16@98d7ba07	Cleartext-Password	:=	ycc2a6
37	R17@98d7ba07	Cleartext-Password	:=	4x2654
38	R18@98d7ba07	Cleartext-Password	:=	c2adcx
39	R19@98d7ba07	Cleartext-Password	:=	6785df
40	R20@98d7ba07	Cleartext-Password	:=	c457da
41	R21@98d7ba07	Cleartext-Password	:=	ye83b9
42	R22@98d7ba07	Cleartext-Password	:=	y7fd22
43	R23@98d7ba07	Cleartext-Password	:=	2ecc4y
44	R24@98d7ba07	Cleartext-Password	:=	f6cf2y
45	R25@98d7ba07	Cleartext-Password	:=	aaeaxc
46	R26@98d7ba07	Cleartext-Password	:=	e4x2ce
47	R27@98d7ba07	Cleartext-Password	:=	ba94cc
48	R28@98d7ba07	Cleartext-Password	:=	a5c7e2
49	R29@98d7ba07	Cleartext-Password	:=	df2ead
50	R30@98d7ba07	Cleartext-Password	:=	a26y3a
51	R31@98d7ba07	Cleartext-Password	:=	bcf45b
52	R32@98d7ba07	Cleartext-Password	:=	a896a8
53	R33@98d7ba07	Cleartext-Password	:=	d7c583
54	R34@98d7ba07	Cleartext-Password	:=	bfda29
55	R35@98d7ba07	Cleartext-Password	:=	e6fby9
56	R36@98d7ba07	Cleartext-Password	:=	bxff43
57	R37@98d7ba07	Cleartext-Password	:=	b2ca29
58	R38@98d7ba07	Cleartext-Password	:=	x53by8
59	R39@98d7ba07	Cleartext-Password	:=	xbxy95
60	R40@98d7ba07	Cleartext-Password	:=	f96xab
61	R41@98d7ba07	Cleartext-Password	:=	x6yxyb
62	R42@98d7ba07	Cleartext-Password	:=	exd536
63	R43@98d7ba07	Cleartext-Password	:=	a4f2f6
64	R44@98d7ba07	Cleartext-Password	:=	ae837y
65	R45@98d7ba07	Cleartext-Password	:=	bxf596
66	66:87:6A:49:95:DA	Cleartext-Password	:=	RLMACAUTH
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
1	R1@98d7ba07	x3d6yd	Access-Accept	2026-07-31 12:04:10.50966+00	\N
2	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-31 12:04:34.260295+00	\N
3	R1@98d7ba07	x3d6yd	Access-Accept	2026-07-31 12:10:45.254653+00	\N
4	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-07-31 12:12:01.317416+00	\N
5	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-07-31 12:15:25.195249+00	\N
6	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-07-31 12:54:47.422314+00	\N
7	R1@98d7ba07	x3d6yd	Access-Accept	2026-07-31 12:57:01.323007+00	\N
8	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-07-31 17:08:11.751186+00	\N
9	R1@98d7ba07	x3d6yd	Access-Reject	2026-07-31 17:08:17.048442+00	\N
10	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-31 17:21:36.536714+00	\N
11	66:87:6A:49:95:DA	RLMACAUTH	Access-Reject	2026-07-31 17:25:59.856267+00	\N
12	R1@98d7ba07	x3d6yd	Access-Accept	2026-07-31 17:34:46.466746+00	\N
13	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-31 18:16:58.339648+00	\N
14	R43@98d7ba07	a4f2f6	Access-Accept	2026-07-31 18:18:06.135455+00	\N
\.


--
-- Data for Name: radreply; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radreply (id, username, attribute, op, value) FROM stdin;
317	R3@98d7ba07	Mikrotik-Rate-Limit	= 	5M/5M
318	R3@98d7ba07	Session-Timeout	= 	3564
405	R4@98d7ba07	Session-Timeout	:=	40360
406	R4@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
407	R5@98d7ba07	Session-Timeout	:=	225134
408	R5@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
409	R6@98d7ba07	Session-Timeout	:=	9917
410	R6@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
411	R7@98d7ba07	Session-Timeout	:=	510083
412	R7@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
413	R8@98d7ba07	Session-Timeout	:=	15048
414	R8@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
415	R9@98d7ba07	Session-Timeout	:=	4932
416	R9@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
417	R10@98d7ba07	Session-Timeout	:=	38027
418	R10@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
419	R11@98d7ba07	Session-Timeout	:=	6169
420	R11@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
421	R12@98d7ba07	Session-Timeout	:=	5770
422	R12@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
423	R13@98d7ba07	Session-Timeout	:=	44781
424	R13@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
425	R14@98d7ba07	Session-Timeout	:=	46874
426	R14@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
427	R15@98d7ba07	Session-Timeout	:=	42149
428	R15@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
429	R16@98d7ba07	Session-Timeout	:=	35855
430	R16@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
431	R17@98d7ba07	Session-Timeout	:=	38806
432	R17@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
433	R18@98d7ba07	Session-Timeout	:=	37732
434	R18@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
435	R19@98d7ba07	Session-Timeout	:=	13126
436	R19@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
437	R20@98d7ba07	Session-Timeout	:=	2804
438	R20@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
439	R21@98d7ba07	Session-Timeout	:=	55043
440	R21@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
441	R22@98d7ba07	Session-Timeout	:=	81393
442	R22@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
443	R23@98d7ba07	Session-Timeout	:=	38813
444	R23@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
445	R24@98d7ba07	Session-Timeout	:=	75396
446	R24@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
447	R25@98d7ba07	Session-Timeout	:=	11819
448	R25@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
449	R26@98d7ba07	Session-Timeout	:=	2300
450	R26@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
451	R27@98d7ba07	Session-Timeout	:=	7488
452	R27@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
453	R28@98d7ba07	Session-Timeout	:=	3678
454	R28@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
455	R29@98d7ba07	Session-Timeout	:=	82849
456	R29@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
457	R30@98d7ba07	Session-Timeout	:=	17396
458	R30@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
459	R31@98d7ba07	Session-Timeout	:=	23607
460	R31@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
461	R32@98d7ba07	Session-Timeout	:=	11184
462	R32@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
463	R33@98d7ba07	Session-Timeout	:=	41000
464	R33@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
465	R34@98d7ba07	Session-Timeout	:=	45699
466	R34@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
467	R35@98d7ba07	Session-Timeout	:=	17941
468	R35@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
469	R36@98d7ba07	Session-Timeout	:=	80164
470	R36@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
471	R37@98d7ba07	Session-Timeout	:=	17830
472	R37@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
473	R38@98d7ba07	Session-Timeout	:=	29007
474	R38@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
475	R39@98d7ba07	Session-Timeout	:=	7283
476	R39@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
477	R40@98d7ba07	Session-Timeout	:=	12805
478	R40@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
479	R41@98d7ba07	Session-Timeout	:=	10902
480	R41@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
481	R42@98d7ba07	Session-Timeout	:=	36702
482	R42@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
483	R43@98d7ba07	Session-Timeout	:=	42497
484	R43@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
485	R44@98d7ba07	Session-Timeout	:=	78134
486	R44@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
487	R45@98d7ba07	Session-Timeout	:=	28790
488	R45@98d7ba07	Mikrotik-Rate-Limit	:=	5M/5M
507	66:87:6A:49:95:DA	Session-Timeout	:=	41850
508	66:87:6A:49:95:DA	Mikrotik-Rate-Limit	:=	5M/5M
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
deab2c52-a8d2-48ec-a111-768796d223de	98d7ba07-2dd2-42d0-819e-e438ea390565	signup_bonus	50.0000	\N	\N	\N	\N	50.0000	\N	completed	Welcome bonus on signup	2026-07-31 10:40:54.834569+00
dc77b341-f81a-471e-9fbc-37c8fd059827	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	49.0000	\N	completed	SMS sent	2026-07-31 10:48:42.209162+00
a5031050-81a4-4170-ae4e-280f0a8a1777	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	48.0000	\N	completed	SMS sent	2026-07-31 11:12:04.194489+00
c2bdf5e6-9f90-4441-ad40-56adf0fe8ff4	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	47.0000	\N	completed	SMS sent	2026-07-31 11:16:00.920769+00
ace535ef-9ad8-4dc5-888d-e55f30cf2c74	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	46.0000	\N	completed	SMS sent	2026-07-31 12:57:00.814644+00
295a3894-f24b-4ff5-939e-a00b5c559cd1	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	45.0000	\N	completed	SMS sent	2026-07-31 16:52:35.903395+00
bf1d059a-7b3e-4830-a4fc-8bb33f15199f	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	44.0000	\N	completed	SMS sent	2026-07-31 17:10:03.820803+00
a43d95f1-d0d3-43d3-9510-e4ccfedf6549	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	43.0000	\N	completed	SMS sent	2026-07-31 17:27:43.675872+00
8acb10ea-0695-4d1d-8d61-7b2b4cc43f9f	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	42.0000	\N	completed	SMS sent	2026-07-31 17:33:05.569871+00
6abd88cb-6560-483f-be3e-ec803c388ded	98d7ba07-2dd2-42d0-819e-e438ea390565	consumption	-1.0000	\N	\N	\N	\N	41.0000	\N	completed	SMS sent	2026-07-31 17:35:00.390821+00
\.


--
-- Data for Name: sms_logs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_logs (id, isp_id, recipient, message, gateway, gateway_message_id, status, cost, sent_at) FROM stdin;
efab6920-1ad2-42fc-b80b-8c36e3cd5761	98d7ba07-2dd2-42d0-819e-e438ea390565	254704994652	Your RumaLink verification code is 699252. It expires in 10 minutes. Do not share it.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-31 10:41:46.169826+00
05309612-a7e5-4b87-b39f-f2efd083c164	98d7ba07-2dd2-42d0-819e-e438ea390565	254704994652	Your RumaLink verification code is 414016. It expires in 10 minutes. Do not share it.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-31 10:44:52.605718+00
7c06fd99-a8f2-4674-b836-724518049e65	98d7ba07-2dd2-42d0-819e-e438ea390565	254740258495	Your RumaLink verification code is 762184. It expires in 10 minutes. Do not share it.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-31 10:45:05.089966+00
be50cdef-41fd-48bc-998d-6dfeb3928d56	98d7ba07-2dd2-42d0-819e-e438ea390565	254704994652	Your RumaLink verification code is 491998. It expires in 10 minutes. Do not share it.	rumalink	\N	sent	\N	2026-07-31 10:48:42.211715+00
3263e7a8-3ed6-4094-9091-05253ef71d38	98d7ba07-2dd2-42d0-819e-e438ea390565	254740258495	Rumalink: 1 Hour activated.\nUsername: R1\nPassword: x3d6yd\nExpires: 31 Jul 2026, 15:11\nReceipt: UGV1311IIM	rumalink	\N	sent	\N	2026-07-31 11:12:04.196989+00
083fb953-a6b7-41df-a618-37632cb83759	98d7ba07-2dd2-42d0-819e-e438ea390565	254740258495	Rumalink: 1 Hour activated.\nUsername: R1\nPassword: x3d6yd\nExpires: 31 Jul 2026, 15:15\nReceipt: UGV1311EHR	rumalink	\N	sent	\N	2026-07-31 11:16:00.922609+00
765a849a-d546-46b1-844c-38acfc03453a	98d7ba07-2dd2-42d0-819e-e438ea390565	254740258495	Rumalink: 1 Hour activated.\nUsername: R1\nPassword: x3d6yd\nExpires: 31 Jul 2026, 16:56\nReceipt: UGV1311SNA	rumalink	\N	sent	\N	2026-07-31 12:57:00.816732+00
c0793c94-544d-4f7b-926c-8fadeceff787	98d7ba07-2dd2-42d0-819e-e438ea390565	0740258495	Rumalink: SMS gateway test - expiry notices are working.	rumalink	\N	sent	\N	2026-07-31 16:52:35.906658+00
01062fb7-bf10-4495-9207-8c3bca933ba3	98d7ba07-2dd2-42d0-819e-e438ea390565	254740258495	Rumalink: 1 Hour activated.\nUsername: R3\nPassword: 35c5c4\nExpires: 31 Jul 2026, 21:09\nReceipt: UGV13135UC	rumalink	\N	sent	\N	2026-07-31 17:10:03.823394+00
b8ef5bd6-03e1-4ca7-bf8a-9a76b5401a17	98d7ba07-2dd2-42d0-819e-e438ea390565	254740258495	Rumalink: 1 Hour activated for Bktv.\nIt connects automatically — no login needed.\nExpires: 31 Jul 2026, 23:09\nReceipt: UGV13136DE	rumalink	\N	sent	\N	2026-07-31 17:27:43.677789+00
cb3beea8-7478-4984-84c9-43777d4a4296	98d7ba07-2dd2-42d0-819e-e438ea390565	254740258495	Rumalink: 1 Hour activated for Bktv.\nIt connects automatically — no login needed.\nExpires: 31 Jul 2026, 21:32\nReceipt: UGV1313C8D	rumalink	\N	sent	\N	2026-07-31 17:33:05.572248+00
6fbe63fc-ffe8-46ec-bb9d-70330c7624f1	98d7ba07-2dd2-42d0-819e-e438ea390565	254740258495	Rumalink: 1 Hour activated.\nUsername: R1\nPassword: x3d6yd\nExpires: 31 Jul 2026, 21:34\nReceipt: UGV1313B05	rumalink	\N	sent	\N	2026-07-31 17:35:00.392771+00
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
98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	66:87:6A:49:95:DA	2026-07-31	10321499	40964035	2026-07-31 18:18:01.715244+00
98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	R1@98d7ba07	2026-07-31	17870616	73147231	2026-07-31 18:18:01.715244+00
98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	R43@98d7ba07	2026-07-31	11767432	28162176	2026-07-31 18:21:02.10499+00
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
d5757ac1a7da8db9a166212b87a96044	8000001e	66:87:6A:49:95:DA	98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	8385683	21012362	2026-07-31 12:18:02.509682+00
cd01a546b83be7ec83ef4f7802d2b21c	80000022	R1@98d7ba07	98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	3262766	3880689	2026-07-31 13:59:01.344798+00
1b62e3c0fd434a5cde47dddae86c8d1a	80000028	66:87:6A:49:95:DA	98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	60	260	2026-07-31 18:20:02.506332+00
adebc80993ebcce674e52f880966d765	80000027	R1@98d7ba07	98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	14607850	69266542	2026-07-31 18:20:02.506332+00
4f2243ebb9ac81077a50ae3e5123a37a	80000025	66:87:6A:49:95:DA	98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	1935756	19951413	2026-07-31 17:28:02.74825+00
8764214b21f3eceb3b9652eef25d4d15	80000029	R43@98d7ba07	98d7ba07-2dd2-42d0-819e-e438ea390565	c9ef146c-52cc-4c59-81e0-b97414e528a5	11767432	28162176	2026-07-31 18:21:02.10499+00
\.


--
-- Data for Name: verification_codes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_codes (id, isp_id, channel, target, code_hash, expires_at, attempts, consumed_at, ip, created_at, selector) FROM stdin;
1	98d7ba07-2dd2-42d0-819e-e438ea390565	email	rumalinkenterprise@gmail.com	b402e182fe48f1e3.b71bbae0bda5ef398439033d4b8d2e5ffa3dced184624c91e0e89688b1e35211	2026-08-01 10:40:55.896349+00	0	2026-07-31 10:41:28.454744+00	102.205.237.69	2026-07-31 10:40:55.896349+00	d87c1e01e17b
2	98d7ba07-2dd2-42d0-819e-e438ea390565	phone	254704994652	306d1cda9a775a2a.7e806f6d0b0b9889094dc2576aad687b12129ddd60957ec38bbff39024cb7ef0	2026-07-31 10:51:45.999611+00	0	\N	102.205.237.69	2026-07-31 10:41:45.999611+00	\N
3	98d7ba07-2dd2-42d0-819e-e438ea390565	phone	254704994652	c9920b15a900e985.933090e2559d0c773e186d96d1e7d964b4b8fa59eaa16b2f5e400fbb3e04251f	2026-07-31 10:54:52.463163+00	0	\N	102.205.237.69	2026-07-31 10:44:52.463163+00	\N
4	98d7ba07-2dd2-42d0-819e-e438ea390565	phone	254740258495	d6a0e8da04716ae6.cc9f781ba959f5ea634a3d4ed497f4db20cc449301ec5dae0a7ec9883b5125f0	2026-07-31 10:55:04.94566+00	0	\N	102.205.237.69	2026-07-31 10:45:04.94566+00	\N
5	98d7ba07-2dd2-42d0-819e-e438ea390565	phone	254704994652	848eb8d726310331.463141d043bc1d6ad06a7aaacdaa77aa5aa6c20eada9e4b1e1c807da04f2bfc6	2026-07-31 10:58:42.027572+00	0	2026-07-31 10:49:07.561647+00	102.205.237.69	2026-07-31 10:48:42.027572+00	\N
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

SELECT pg_catalog.setval('public.radacct_radacctid_seq', 7, true);


--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.radcheck_delete_audit_id_seq', 141, true);


--
-- Name: radcheck_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radcheck_id_seq', 66, true);


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

SELECT pg_catalog.setval('public.radpostauth_id_seq', 14, true);


--
-- Name: radreply_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radreply_id_seq', 508, true);


--
-- Name: system_health_alerts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_health_alerts_id_seq', 1, true);


--
-- Name: system_health_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_health_id_seq', 563, true);


--
-- Name: verification_codes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verification_codes_id_seq', 5, true);


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

\unrestrict 27TVqGAMR3kp6Z2toTc4coJdWeGJY7vE0ROsq8NSHSYWN8BF59mAZDGke1fz3E0

