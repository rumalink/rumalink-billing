--
-- PostgreSQL database dump
--

\restrict hjXVT7uhDNJHE1ItaCEyyylG9aN2C1agEueGZRAwUs5J8VrH65kOgxQvMbposLg

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
    import_batch text
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
e0556dcb-b203-4e85-b0c4-bd657bddcf62	RumaLink Admin	admin@rumalink.co.ke	$2a$12$lW4s6qSv6dP4ZBV4CMkUq.hwqqCiaphkhsZ6qELmJdG7MwF1axeje	superadmin	t	2026-07-29 06:05:14.966856+00	2026-05-24 08:18:35.982073+00	2026-05-24 08:18:35.982073+00
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
30e26bef-2773-4b07-a6b7-78c696ad2d5b	44a1539e-4978-474e-987b-e817d98769f7	5008ec4b-4516-46b6-ba73-05d88577a3c5	0.90	0.0300	\N	\N	f	\N	2026-07-29 06:30:00.56426+00
38bcdc87-3173-4d4d-8d9e-04a70a14aca2	44a1539e-4978-474e-987b-e817d98769f7	0cb2450e-0bee-490e-b2f4-b57175b66d87	0.00	0.0300	\N	\N	f	\N	2026-07-29 08:38:42.188152+00
511d0bf6-c2e7-4f79-9a88-37d74eb89669	44a1539e-4978-474e-987b-e817d98769f7	7e193459-dd41-4d3b-bab5-2d98d57f46bb	0.15	0.0300	\N	\N	f	\N	2026-07-29 08:59:00.765911+00
169c2646-ace4-4dac-8b3b-98410760f3d0	44a1539e-4978-474e-987b-e817d98769f7	bad374a7-f9e9-44ad-9e81-b9e1bbfc1316	0.90	0.0300	\N	\N	f	\N	2026-07-29 09:39:00.761553+00
8e653667-8cee-412b-8a14-c548f421103b	44a1539e-4978-474e-987b-e817d98769f7	67f61612-5454-4cf6-a4cc-5a8fa078ce3f	0.90	0.0300	\N	\N	f	\N	2026-07-29 09:56:00.651284+00
cece72d8-04ab-45ed-895a-fa34797ac458	44a1539e-4978-474e-987b-e817d98769f7	986a32ee-5bc6-4762-a251-e97506ea2f1c	0.15	0.0300	\N	\N	f	\N	2026-07-29 10:10:00.950024+00
b4b00d08-3a39-4078-bd34-2d073f28128b	44a1539e-4978-474e-987b-e817d98769f7	cfea8261-76a4-4846-b3ea-7eed2ed60d67	0.15	0.0300	\N	\N	f	\N	2026-07-29 10:15:00.111814+00
5fe107f7-ad52-49cf-9b34-110608aac9b0	44a1539e-4978-474e-987b-e817d98769f7	ed208752-aafe-4282-8f86-e625aee706d6	0.15	0.0300	\N	\N	f	\N	2026-07-29 10:29:00.49837+00
7c759b5a-af73-4842-beee-3d9c23104441	44a1539e-4978-474e-987b-e817d98769f7	21d6e9a7-d565-4b1a-82ec-daed164a6d2f	0.15	0.0300	\N	\N	f	\N	2026-07-29 10:34:00.627005+00
3b8b9d6d-8ca3-4fdf-bd22-0da06a855ab1	44a1539e-4978-474e-987b-e817d98769f7	ab9a0b92-5348-4456-9de0-a2e0bf923311	0.15	0.0300	\N	\N	f	\N	2026-07-29 10:50:00.211335+00
e33a9bf3-4ecf-4d1d-984c-f60be4f53905	44a1539e-4978-474e-987b-e817d98769f7	9bc7ab8e-3dac-4c01-bcc5-954bd27473a6	0.15	0.0300	\N	\N	f	\N	2026-07-29 13:48:00.618501+00
e6e03d6d-710e-467a-ac75-1e995144e43e	44a1539e-4978-474e-987b-e817d98769f7	a39942aa-e58d-4b8d-8af1-986e4044c286	0.15	0.0300	\N	\N	f	\N	2026-07-29 19:30:00.40364+00
9fb613ad-9b7d-4f60-a4fa-a2406f489ca0	44a1539e-4978-474e-987b-e817d98769f7	7eeed7ef-6801-4de1-85f1-6d5aba1bb668	0.15	0.0300	\N	\N	f	\N	2026-07-29 19:31:00.427217+00
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
f3700d16-956e-46a7-83d4-f20a8ef173df	44a1539e-4978-474e-987b-e817d98769f7	Benatv	BC:2B:02:3A:7F:7C	\N	acd91855-5361-4a7c-9483-471ead9ff73c	\N	9a35c8d3-75c8-4778-b8d6-8a6a1c40fee7	2026-07-29 14:46:09.000867+00	f	2026-07-29 09:36:27.636763+00	2026-07-29 14:47:02.72747+00	4994952	8280907	1325817	1746035
\.


--
-- Data for Name: hotspot_packages; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_packages (id, isp_id, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, created_at, updated_at) FROM stdin;
9a35c8d3-75c8-4778-b8d6-8a6a1c40fee7	44a1539e-4978-474e-987b-e817d98769f7	\N	1 Hour	\N	5.00	1	5	5	\N	1		t	2026-07-29 06:28:08.002956+00	2026-07-29 06:28:08.002956+00
079b1bed-25c2-4e38-99dc-232b9a5e2f0f	44a1539e-4978-474e-987b-e817d98769f7	\N	24 Hours	\N	30.00	24	10	10	\N	1		t	2026-07-29 06:28:31.584741+00	2026-07-29 06:28:31.584741+00
\.


--
-- Data for Name: hotspot_sessions; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_sessions (id, isp_id, voucher_id, nas_id, radius_session_id, mac_address, ip_address, nas_ip, bytes_downloaded, bytes_uploaded, session_time_seconds, status, started_at, ended_at, terminate_cause) FROM stdin;
\.


--
-- Data for Name: hotspot_vouchers; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.hotspot_vouchers (id, isp_id, package_id, nas_id, code, batch_id, status, used_by_mac, used_by_ip, used_at, expires_at, bytes_downloaded, bytes_uploaded, time_used_seconds, is_paid, amount_paid, payment_method, payment_reference, created_at, updated_at, buyer_phone, sms_sent, expiry_sms_sent, payment_id, is_test, password, is_tv, tv_mac, created_by_isp, import_batch) FROM stdin;
b55a9329-500f-48c3-bcec-6944947b142d	44a1539e-4978-474e-987b-e817d98769f7	079b1bed-25c2-4e38-99dc-232b9a5e2f0f	\N	R1	\N	active	66:87:6A:49:95:DA	\N	\N	2026-07-30 06:29:11.925954+00	0	0	0	t	\N	\N	\N	2026-07-29 06:28:46.262815+00	2026-07-29 06:30:00.553245+00	254740258495	f	f	5008ec4b-4516-46b6-ba73-05d88577a3c5	f	6c53fe	f	\N	f	\N
6ea8ccc0-23e1-4cb2-8dfd-310d16abc85d	44a1539e-4978-474e-987b-e817d98769f7	079b1bed-25c2-4e38-99dc-232b9a5e2f0f	\N	R2	\N	unused	\N	\N	\N	\N	0	0	0	f	\N	\N	\N	2026-07-29 08:18:37.740581+00	2026-07-29 08:18:37.740581+00	254718275827	f	f	7776d755-31bd-43dd-922f-e9000ba98b8a	f	x6bd28	f	\N	f	\N
acd91855-5361-4a7c-9483-471ead9ff73c	44a1539e-4978-474e-987b-e817d98769f7	9a35c8d3-75c8-4778-b8d6-8a6a1c40fee7	\N	R6	\N	expired	BC:2B:02:3A:7F:7C	\N	\N	2026-07-29 14:46:09.000867+00	0	0	0	t	\N	\N	\N	2026-07-29 10:48:54.233945+00	2026-07-29 14:47:00.27021+00	254117195942	f	f	9bc7ab8e-3dac-4c01-bcc5-954bd27473a6	f	3fdyeb	t	BC:2B:02:3A:7F:7C	f	\N
60b4e26b-04bb-4357-9f09-972ab9cd30e3	44a1539e-4978-474e-987b-e817d98769f7	9a35c8d3-75c8-4778-b8d6-8a6a1c40fee7	\N	R7	\N	expired	\N	\N	\N	2026-07-29 20:29:04.738357+00	0	0	0	t	\N	\N	\N	2026-07-29 19:28:47.88088+00	2026-07-29 20:30:02.478155+00	254758317799	f	f	a39942aa-e58d-4b8d-8af1-986e4044c286	f	xyd57b	f	\N	f	\N
6482bf5d-55ed-49e7-98a7-a7a06ef4aa83	44a1539e-4978-474e-987b-e817d98769f7	9a35c8d3-75c8-4778-b8d6-8a6a1c40fee7	\N	R8	\N	expired	\N	\N	\N	2026-07-29 20:30:55.732442+00	0	0	0	t	\N	\N	\N	2026-07-29 19:30:39.45373+00	2026-07-29 20:31:00.21221+00	254799596989	f	f	7eeed7ef-6801-4de1-85f1-6d5aba1bb668	f	2373f4	f	\N	f	\N
ebf4e543-c6be-4aaa-9c03-6fda8c033887	44a1539e-4978-474e-987b-e817d98769f7	9a35c8d3-75c8-4778-b8d6-8a6a1c40fee7	\N	R5	\N	unused	\N	\N	\N	\N	0	0	0	f	\N	\N	\N	2026-07-29 10:47:40.413501+00	2026-07-29 10:47:40.413501+00	254117195942	f	f	e3c3e5d6-8377-4e57-a706-ff8c936755ea	f	7xaf9f	f	\N	f	\N
a1584fc9-36fe-433e-aac3-32048ac9c0a0	44a1539e-4978-474e-987b-e817d98769f7	9a35c8d3-75c8-4778-b8d6-8a6a1c40fee7	\N	R4	\N	expired	\N	\N	\N	2026-07-29 09:58:34.916879+00	0	0	0	t	\N	\N	\N	2026-07-29 08:58:15.678424+00	2026-07-29 09:59:00.650207+00	254796829688	f	f	7e193459-dd41-4d3b-bab5-2d98d57f46bb	f	y73a37	f	\N	f	\N
468b0a7a-4d9e-43d9-9158-c6a5570f0445	44a1539e-4978-474e-987b-e817d98769f7	9a35c8d3-75c8-4778-b8d6-8a6a1c40fee7	\N	R3	\N	expired	\N	\N	\N	2026-07-29 11:33:27.064669+00	0	0	0	t	\N	\N	\N	2026-07-29 08:34:32.447519+00	2026-07-29 11:34:00.520576+00	254117195942	f	f	21d6e9a7-d565-4b1a-82ec-daed164a6d2f	f	d8ba64	f	\N	f	\N
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
6dcf4dd1-8194-4cfe-88b8-46265f116605	44a1539e-4978-474e-987b-e817d98769f7	mpesa_stk	4322307	4322307	7V4yYILZxVLaYRalxSX7vLNKARpAItO9YwOzlA0pCCQ4KZQ0	b0eWBg6Cv0G558cMO6OhAbAKrJJ5wDvMAybO9axDEB1ZVastiVAAjh2HKwrz0VRw	3317f5d8845fbe32c8e8435e1b79934d36ae1c303f9383b5d8a35ac36d4720b6	f	f	\N	\N	\N	\N	\N	\N	\N	till	\N	\N	t	f	t	2026-07-29 08:36:12.904464+00	2026-07-29 08:36:12.904464+00	\N
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
6396369f-8ecb-402c-8950-90cbec3dd389	44a1539e-4978-474e-987b-e817d98769f7	payment	30.00	\N	30.00	IntaSend payment - UGT130S7OJ	5008ec4b-4516-46b6-ba73-05d88577a3c5	2026-07-29 06:30:00.577993+00
9f221921-03cf-4846-9b70-884bb1057206	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGTJK0Q3I6	7e193459-dd41-4d3b-bab5-2d98d57f46bb	2026-07-29 08:59:00.774035+00
62d76d00-e523-4c28-85b8-1560ef6e846a	44a1539e-4978-474e-987b-e817d98769f7	payment	30.00	\N	\N	IntaSend payment - UGTC80PNYY	bad374a7-f9e9-44ad-9e81-b9e1bbfc1316	2026-07-29 09:39:00.76772+00
39650601-7aa5-4b11-b0d3-6f5276d1923f	44a1539e-4978-474e-987b-e817d98769f7	payment	30.00	\N	\N	IntaSend payment - UGTC80PQPY	67f61612-5454-4cf6-a4cc-5a8fa078ce3f	2026-07-29 09:56:00.662301+00
f2eb587c-8198-45b0-b977-0ae33556df14	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGTC80PV35	986a32ee-5bc6-4762-a251-e97506ea2f1c	2026-07-29 10:10:00.964363+00
87d02d5a-31c8-4dff-9b31-d0f891bd2d8f	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGTC80PR44	cfea8261-76a4-4846-b3ea-7eed2ed60d67	2026-07-29 10:15:00.120149+00
64b7815e-7576-4481-aeb8-4fea4d02d83a	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGTC80PRDY	ed208752-aafe-4282-8f86-e625aee706d6	2026-07-29 10:29:00.505668+00
a96f6d30-a995-4c60-bffc-17110bf9be80	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGTC80Q0R3	21d6e9a7-d565-4b1a-82ec-daed164a6d2f	2026-07-29 10:34:00.648462+00
7a4a9b04-7815-4fe7-a966-f3f3e10c070c	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGTC80PVVW	ab9a0b92-5348-4456-9de0-a2e0bf923311	2026-07-29 10:50:00.221293+00
56ed2307-ef81-41a3-944e-002a5fe87b64	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGTC80QKL2	9bc7ab8e-3dac-4c01-bcc5-954bd27473a6	2026-07-29 13:48:00.637473+00
f011cce3-3e5e-475b-bcb4-c9da7ff9cc1f	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGT391E2KW	a39942aa-e58d-4b8d-8af1-986e4044c286	2026-07-29 19:30:00.41172+00
84cba34f-5637-41a0-9613-999abb77c4e5	44a1539e-4978-474e-987b-e817d98769f7	payment	5.00	\N	\N	IntaSend payment - UGTMT12RE6	7eeed7ef-6801-4de1-85f1-6d5aba1bb668	2026-07-29 19:31:00.434966+00
\.


--
-- Data for Name: isps; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.isps (id, company_name, owner_name, email, phone, password_hash, plan_type, status, county, town, address, api_key, api_secret, webhook_url, wallet_balance, commission_rate, pppoe_rate_per_user, total_earned, total_commission_paid, sms_gateway, sms_api_key, sms_sender_id, logo_url, timezone, currency, email_verified, email_verify_token, password_reset_token, password_reset_expires, trial_ends_at, last_login, created_at, updated_at, sms_username, sms_partner_id, sms_api_secret, support_number, hotspot_counter, subscription_started_at, license_expires_at, billing_window_start, license_status, billing_exempt, sms_balance, phone_verified, phone_verified_at, email_verified_at) FROM stdin;
44a1539e-4978-474e-987b-e817d98769f7	Rumalink	Benard	rumalinkenterprise@gmail.com	0117195942	$2a$12$r3uzJJsh/T3Avs.JfLL5vOEluaoKZ2bhi2oLUr21iGZjdjPHJe8zu	both	active	Nairobi	Nairobi	\N	fb280b34-2b40-4b1c-94e7-ce4783c60450	47a55bc4f4f710cd703dfc127744d6118ce174976ac39cb3026db2d29059fd61	\N	\N	0.0300	32.25	140.00	4.05	rumalink			\N	Africa/Nairobi	KES	t	\N	\N	\N	2026-08-28 06:14:50.340776+00	2026-07-29 20:00:28.990344+00	2026-07-29 06:14:50.340776+00	2026-07-29 06:19:31.11532+00	\N	\N	\N	\N	8	\N	\N	\N	trial	f	34.0000	t	2026-07-29 06:17:03.277722+00	2026-07-29 06:15:48.310135+00
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
9d6b8c61-725a-443b-a1ec-4467f5dfd34f	44a1539e-4978-474e-987b-e817d98769f7	5008ec4b-4516-46b6-ba73-05d88577a3c5	ws_CO_29072026092846019740258495	3d57-4feb-a16b-cbb513bab6ed15035601	\N	\N	30.00	UGT130S7OJ	254740258495	2026-07-29 06:29:11.94039+00	completed	\N	2026-07-29 06:28:46.254059+00
84af864e-f191-477a-915b-48439f6254aa	44a1539e-4978-474e-987b-e817d98769f7	7776d755-31bd-43dd-922f-e9000ba98b8a	RLIMS5TC1SBT8J8	RLIMS5TC1SBT8J8	\N	\N	30.00	\N	254718275827	\N	pending	\N	2026-07-29 08:18:37.454095+00
348b27bf-6652-4215-bae4-ec5f199391fb	44a1539e-4978-474e-987b-e817d98769f7	f2695799-a60c-453f-bdc7-119388f902f9	ws_CO_29072026113432651117195942	2bb7-403f-8db1-02327420fbff11030186	\N	\N	30.00	\N	254117195942	\N	pending	\N	2026-07-29 08:34:32.442869+00
b222f647-d1ba-48cb-9574-2bc440e90a52	44a1539e-4978-474e-987b-e817d98769f7	5f49e328-0de1-4ab4-b3e9-4285c1b5e448	ws_CO_29072026113452330117195942	2bb7-403f-8db1-02327420fbff11030591	\N	\N	30.00	\N	254117195942	\N	pending	\N	2026-07-29 08:34:52.391037+00
6b0dcd70-c3c7-4cfd-be73-795026cc12c7	44a1539e-4978-474e-987b-e817d98769f7	687d65d7-2c54-4cf4-8852-bfd9e9e6506a	ws_CO_29072026113635194117195942	1f3b-4d82-81e1-8dbb29a4d5991763606	\N	\N	30.00	\N	254117195942	\N	pending	\N	2026-07-29 08:36:35.455014+00
4bcb8cc9-dbe5-4720-b604-79d93d730a95	44a1539e-4978-474e-987b-e817d98769f7	7e193459-dd41-4d3b-bab5-2d98d57f46bb	ws_CO_29072026115815033796829688	3288-4b68-9ea3-0fad426f8cf37481019	\N	\N	5.00	UGTJK0Q3I6	254796829688	2026-07-29 08:58:34.918864+00	completed	\N	2026-07-29 08:58:15.673202+00
aa2d8916-6789-4898-a9f2-52d7b0263cbc	44a1539e-4978-474e-987b-e817d98769f7	d06a9e3e-fde3-44a2-a944-69201cea4808	ws_CO_29072026121024713117195942	f872-420b-96b9-106216be206b13794490	\N	\N	5.00	\N	254117195942	\N	pending	\N	2026-07-29 09:10:24.604585+00
f5ea075e-ac02-403b-b3db-053e8c50a738	44a1539e-4978-474e-987b-e817d98769f7	7da5c03a-7f0a-4357-8f11-5bfbeb20c182	ws_CO_29072026123253637117195942	1db1-4767-927e-0058bc633bcd15809621	\N	\N	5.00	\N	254117195942	\N	pending	\N	2026-07-29 09:32:53.246431+00
87d3a1e4-379b-4061-b584-a60ff680b4cc	44a1539e-4978-474e-987b-e817d98769f7	23c53bf2-adf0-4e5a-87ce-a416eaaad9dd	ws_CO_29072026123337038117195942	df07-4e83-abab-4b432db6736c4195327	\N	\N	5.00	\N	254117195942	\N	pending	\N	2026-07-29 09:33:37.776219+00
0e5539cc-a3ba-49f6-8b28-e6077fd9066b	44a1539e-4978-474e-987b-e817d98769f7	bad374a7-f9e9-44ad-9e81-b9e1bbfc1316	ws_CO_29072026123810150117195942	12c7-47ed-9822-01985aac1bc27554568	\N	\N	30.00	UGTC80PNYY	254117195942	2026-07-29 09:38:32.362936+00	completed	\N	2026-07-29 09:38:10.380195+00
026868f3-aa07-4502-b2ec-e8cdb8696a1e	44a1539e-4978-474e-987b-e817d98769f7	67f61612-5454-4cf6-a4cc-5a8fa078ce3f	ws_CO_29072026125404952117195942	7f71-4c04-9612-d2bf1440b0d51088876	\N	\N	30.00	UGTC80PQPY	254117195942	2026-07-29 09:54:22.54804+00	completed	\N	2026-07-29 09:54:04.411853+00
185d05b2-9f55-4530-bb11-ca6806148599	44a1539e-4978-474e-987b-e817d98769f7	986a32ee-5bc6-4762-a251-e97506ea2f1c	ws_CO_29072026130940634117195942	29a0-4d51-8b04-cf456933339a7577999	\N	\N	5.00	UGTC80PV35	254117195942	2026-07-29 10:09:58.57359+00	completed	\N	2026-07-29 10:09:40.58679+00
1295a149-1ada-462e-b7f9-e8598781b696	44a1539e-4978-474e-987b-e817d98769f7	cfea8261-76a4-4846-b3ea-7eed2ed60d67	ws_CO_29072026131348448117195942	782d-4443-86ce-dad3d6615393910558	\N	\N	5.00	UGTC80PR44	254117195942	2026-07-29 10:14:13.590036+00	completed	\N	2026-07-29 10:13:48.434301+00
3de30b94-8926-4c32-bfe8-a999ea8a2c9a	44a1539e-4978-474e-987b-e817d98769f7	ed208752-aafe-4282-8f86-e625aee706d6	ws_CO_29072026132803512117195942	2225-4750-878c-a6bb3717aa6c937788	\N	\N	5.00	UGTC80PRDY	254117195942	2026-07-29 10:28:22.572134+00	completed	\N	2026-07-29 10:28:03.254895+00
d43bf71c-058c-459f-9374-d929af105dbf	44a1539e-4978-474e-987b-e817d98769f7	6dacdc4c-51a4-470c-a19d-769ed020283e	ws_CO_29072026133139341117195942	e6f5-4b3d-93ed-bb868f4972bd862458	\N	\N	5.00	\N	254117195942	\N	pending	\N	2026-07-29 10:31:39.817994+00
8f71a805-87d1-4a49-a7dc-a84dfc91f0c6	44a1539e-4978-474e-987b-e817d98769f7	d590def6-7b0c-4d9e-9385-f7508787d93e	ws_CO_29072026133231640117195942	1db1-4767-927e-0058bc633bcd15896435	\N	\N	5.00	\N	254117195942	\N	pending	\N	2026-07-29 10:32:31.346012+00
ad3075e9-ec0c-406a-9b77-a912e0bbac8c	44a1539e-4978-474e-987b-e817d98769f7	21d6e9a7-d565-4b1a-82ec-daed164a6d2f	ws_CO_29072026133303372117195942	68b0-41e7-a936-79b65ab44f7e10701849	\N	\N	5.00	UGTC80Q0R3	254117195942	2026-07-29 10:33:27.066425+00	completed	\N	2026-07-29 10:33:03.991658+00
e7bca479-e24e-4a3e-adb5-d7e64d231333	44a1539e-4978-474e-987b-e817d98769f7	e3c3e5d6-8377-4e57-a706-ff8c936755ea	ws_CO_29072026134740456117195942	9f15-498f-8d75-f1ac6baed10120646084	\N	\N	5.00	\N	254117195942	\N	pending	\N	2026-07-29 10:47:40.408733+00
efa032bd-5b8e-4226-a8bd-c1cc7dbd6560	44a1539e-4978-474e-987b-e817d98769f7	ab9a0b92-5348-4456-9de0-a2e0bf923311	ws_CO_29072026134854411117195942	782d-4443-86ce-dad3d6615393961957	\N	\N	5.00	UGTC80PVVW	254117195942	2026-07-29 10:49:16.422182+00	completed	\N	2026-07-29 10:48:54.229422+00
7322e770-e62a-4772-afe5-74b0eb45b10a	44a1539e-4978-474e-987b-e817d98769f7	9bc7ab8e-3dac-4c01-bcc5-954bd27473a6	ws_CO_29072026164543404117195942	c5c7-4c07-a82c-dd629e7d85958624208	\N	\N	5.00	UGTC80QKL2	254117195942	2026-07-29 13:46:09.002929+00	completed	\N	2026-07-29 13:45:43.173927+00
0fa852a0-f6ea-4cc0-9350-862bfe250d70	44a1539e-4978-474e-987b-e817d98769f7	a39942aa-e58d-4b8d-8af1-986e4044c286	ws_CO_29072026222847366758317799	4947-4f2a-8801-6e5de9894f9110741625	\N	\N	5.00	UGT391E2KW	254758317799	2026-07-29 19:29:04.740298+00	completed	\N	2026-07-29 19:28:47.875723+00
86e0a396-9736-4107-bf7b-d1c2a8875600	44a1539e-4978-474e-987b-e817d98769f7	7eeed7ef-6801-4de1-85f1-6d5aba1bb668	ws_CO_29072026223039716799596989	4947-4f2a-8801-6e5de9894f9110744278	\N	\N	5.00	UGTMT12RE6	254799596989	2026-07-29 19:30:55.734358+00	completed	\N	2026-07-29 19:30:39.44925+00
\.


--
-- Data for Name: nas; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas (id, nasname, shortname, type, ports, secret, server, community, description) FROM stdin;
1	10.8.0.2	DandoraP3	mikrotik	\N	RMLBF73BCCBA03F4588	\N	\N	RumaLink auto-sync
\.


--
-- Data for Name: nas_devices; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_devices (id, isp_id, name, description, nas_ip, nas_port, secret, provision_token, provision_url, is_provisioned, provisioned_at, mikrotik_identity, mikrotik_version, mikrotik_board, mikrotik_mac, wan_ip, is_online, last_seen, hotspot_enabled, pppoe_enabled, hotspot_profile, pppoe_pool, winbox_port, created_at, updated_at, antishare_enabled, antishare_max_devices, bridged_ports, bridge_ports, hotspot_interface, pppoe_interface, gateway_ip, ip_pool_start, ip_pool_end, dns_primary, dns_secondary, hotspot_network, hotspot_gateway, hotspot_pool_start, hotspot_pool_end, mikrotik_api_user, mikrotik_api_password, remote_winbox_url, provision_step, cpu_load, memory_used_mb, memory_total_mb, disk_used_mb, disk_total_mb, uptime_seconds, wan_interface, available_interfaces, wireguard_private_key, wireguard_public_key, wireguard_ip, radius_secret, winbox_proxy_port, isp_link_status, isp_link_changed_at, isp_link_last_checked, isp_link_consecutive_failures, isp_link_notifications_enabled, multi_wan_mode, wan1_interface, wan1_gateway, wan1_ping_target, wan2_interface, wan2_gateway, wan2_ping_target, multi_wan_check_interval, multi_wan_fail_threshold, lb_weight_wan1, pcc_mode, multi_wan_applied_at, wan_quality_enabled, wan_quality_latency_ms, wan_quality_jitter_ms, wan_quality_loss_pct, wan_quality_trip_count, wan_quality_recover_count, wan_type, wan_pppoe_user, wan_pppoe_pass, wan_static_ip, wan_static_gw, wan_selected, wan_quality_min_mbps) FROM stdin;
0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	DandoraP3	\N	\N	3799	RMLBF73BCCBA03F4588	aaa6dc73-ffdf-4a9a-bd15-57191b3fac40	https://rumalinkenterprise.online/api/provision/aaa6dc73-ffdf-4a9a-bd15-57191b3fac40	t	2026-07-29 06:21:56.257178+00	MikroTik	7.19.6 (stable)	RB951Ui-2HnD	pending	\N	t	2026-07-30 02:28:43.006385+00	t	t	\N	\N	20001	2026-07-29 06:21:44.557643+00	2026-07-30 02:28:43.006385+00	f	1	["ether2", "ether3", "ether4", "wlan1"]	ether3,ether4,ether5	bridge1	ether1	192.168.88.1	192.168.88.10	192.168.88.254	8.8.8.8	8.8.4.4	10.100.0.0/24	10.100.0.1	10.100.0.10	10.100.0.250	rl_0cc4baf5	90628ec5-0df	rumalinkenterprise.online:20001	configured	3	58	128	32	128	0	ether2	ether1,ether2,ether3,ether4,ether5	sNLfOT5uyoGuzufEMioU4eHLnpw2o6Qrc4vPNL6MDFQ=	XAKEkBuBE4241wrYx1Qg9k5bo0rVLl8VOLy1oNSsRH4=	10.8.0.2	95614be0938038368bdfe7189457a1d7	\N	up	2026-07-30 02:13:03.82+00	2026-07-30 02:29:03.19+00	0	t	failover	\N	\N	8.8.8.8	\N	\N	1.1.1.1	10	3	50	both-addresses	2026-07-29 06:24:24.952784+00	t	150	60	2	4	4	pppoe	mikrotiktest2	mikrotik2541028	\N	\N	t	3
\.


--
-- Data for Name: nas_events; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_events (id, nas_id, isp_id, event_type, message, created_at) FROM stdin;
6d514257-7280-4e6c-a49e-c1a7910d127a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	provisioned	Config imported	2026-07-29 06:21:56.294367+00
87e67940-a436-4d4b-ae51-a5c2f9084621	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:25:21.865139+00
4c9a9127-72ba-4040-b232-34644fd2f527	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:25:26.086241+00
a3879f90-2e81-46a8-b442-7503297ae4c7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:25:57.932115+00
f2c0d784-4360-4086-aade-333e4db20fc2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:26:39.182554+00
2a783e76-a8fa-4a74-bca0-7edb221dd163	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:27:16.594154+00
cc13cfc0-a22b-4ff2-b7e4-16f8947cc299	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:27:57.939654+00
ad711a6d-bedf-4561-9f98-c449e45ab79a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:28:29.329672+00
aaebc25b-a030-4b09-93f8-7a4f971ef5f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:28:57.334544+00
43d28c61-0b83-4802-b7a6-17ad322b3e06	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:29:58.246305+00
f4fa0f2e-2de1-492c-b586-4d2075bf2e6c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:30:30.153615+00
82e8657d-a150-4796-aabc-61b8f76b5e00	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:30:58.376295+00
74b9d963-eefc-47c0-adec-4f29071c9b44	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:31:39.314472+00
6fc7ad9d-81a6-4ada-81ed-d55bb6c4848b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:32:17.497018+00
8df9e687-9bf3-46dd-b3fc-8d8764cd3ed1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:32:58.043405+00
156af1af-9a67-4f3a-bd12-721e120def4c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:33:29.754391+00
cc836e2f-e191-43c6-ac89-41a420473072	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:33:58.100649+00
67909dda-da4b-426a-81b2-e858bfd2b102	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:34:30.594031+00
84adecf4-92b4-40d6-b1e0-5645ed2360c3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:35:16.493218+00
4cedc64f-0656-4200-b155-16e6600991b5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:36:00.39277+00
ad3f57e0-870a-4f82-89eb-1439d2712edd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:36:40.202859+00
92e7ae6e-625f-40a5-9e2f-692986139598	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:37:14.83097+00
e6f38966-d230-4e9f-9082-43b3747aa482	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:37:42.889633+00
94ab36ca-fc19-4001-bb73-7d1651044872	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:38:14.558816+00
135e650e-b9ce-44e1-ae95-627562692363	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:38:43.269506+00
5c0ad93a-527c-46a1-9165-4f108a82b755	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:39:14.616385+00
9b482c4c-b5bb-4994-933c-bfd16ff7c39c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:39:42.970752+00
008dced4-adb8-4776-b92d-3935e4cae783	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:40:17.044025+00
bf6a9315-c5e6-463c-b175-581ee78d0abc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:40:58.314445+00
e482483b-161a-4987-a0e2-70c3bb04b679	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:41:30.821477+00
6fc59649-1bf2-488d-9421-3bcdd0b4109f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:42:14.449727+00
0944f524-9bcc-4993-bf47-3ed4f034e948	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:42:44.084453+00
d2626290-c84b-449b-bbe4-13cee2f51981	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:43:17.932527+00
0d8ad2b9-80d6-4628-9ffc-6187cfb4c296	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:43:58.793154+00
ce582a00-5724-4d7f-83ad-10202239e414	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:44:30.274198+00
e73a2eb0-2bac-41a3-be11-78a9939d36d0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:45:17.16485+00
734bba88-5fb2-4d65-af36-34fcdbf21648	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:45:58.582456+00
15ffc289-1310-4039-ba58-677db0345f9b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:46:32.515819+00
692e93b9-06bb-40e1-b071-fdd43cc0c113	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:47:16.269193+00
ebd3fe89-1d51-417a-960f-175f56412bd4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:47:57.578271+00
6da9e078-3b03-40c0-8f94-b886ec088eff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:48:29.451153+00
298d6772-06fb-43ed-9c4f-ac34f672bae8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:48:57.691013+00
46c461e6-2462-4765-8f8a-482d800462f4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:49:29.992972+00
0a300fcb-3f7e-4e69-8370-551fcdb5273f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:50:16.291918+00
f4d0e523-5e59-4f0f-91e2-2429fd27b960	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:50:57.682642+00
60ca065b-33da-4a28-b057-a5e144f8a1f0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:51:39.092935+00
2330ca1a-a834-4b73-bd19-faf0acb0cb01	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:52:14.308333+00
86aa49a1-5ad1-4a43-89c3-102b99f4b39e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:52:43.537146+00
f5c85a5a-1c8a-4ed1-beb9-6b7229d1561e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:53:14.04401+00
c7b15f40-dd53-47b2-8292-79c88839f7e8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:53:43.386407+00
5027448d-ed05-43c9-8e4c-d04f39178431	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:54:16.53115+00
069740c5-822e-432b-9a23-1b0ccdfc8378	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:54:58.753011+00
f65eb5e3-0c56-4cbd-b978-568b405d48c9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:55:29.686774+00
c55a6714-a1aa-473d-a1d0-9eaa7a1bb902	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:55:57.659941+00
f05aef77-bfdc-468c-b6df-66f3fba38f10	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:56:29.612679+00
fcb563a8-e956-4382-accc-239cfe4d8c6a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:56:59.644235+00
6d8980c1-fb65-49cc-9ead-c9e4dbbeb5b4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:57:29.938702+00
f7c042c9-b1fd-45c7-8ca1-dbef427e5cc4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:57:57.519497+00
20438161-cad8-4cb7-aece-d97a663cdb44	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:58:29.877565+00
2cf11428-f195-4272-aed9-ead517e956aa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:58:57.513749+00
4783dcc2-3bbe-4772-9932-dafd7f313b4c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:59:29.73318+00
08b8c0b5-a5e3-40ed-9200-7c63e2bb31f8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 06:59:58.029342+00
54b4b674-2f2c-4577-a676-026c6eaa871c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:00:29.933272+00
15a13986-fb55-4130-82ec-46c3b6509b5c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:00:57.520273+00
81d6dbfc-3240-42eb-b53a-1842568e6aaf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:01:31.149212+00
fd589d0f-012d-4bd6-ac3f-690fd134d061	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:02:14.572064+00
6a8e3f0c-5fab-4f4c-a9cb-ec92cb113c8f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:02:43.098932+00
571b382c-d97d-4b12-a833-b26719cc8784	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:03:15.664691+00
fbb20d9b-f258-487c-b8ea-16fd4f55ac00	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:03:58.531911+00
ca761b8e-4a62-4457-b2e9-2ebe22aa044d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:04:30.175155+00
ded2357c-da75-4357-a5d7-53f528e40741	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:04:57.825342+00
de0547aa-b7ab-4efd-95ac-c106a61dbf06	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:05:29.890451+00
1409f375-8e13-45c6-8f76-b29dfda3d39e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:06:08.823935+00
e74c3632-8160-4949-9b34-71e0f2756b69	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:06:43.472048+00
b8c86846-4eb6-499e-97a3-e599585ddda4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:07:26.295661+00
3f77a346-0ba4-4dc6-b734-9e32f19ddbff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:07:58.451235+00
6206aaad-787f-4b83-8459-4ca68e54ba04	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:08:30.416781+00
47799cc2-96e0-4587-9e58-02e2f6fe1140	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:09:14.702958+00
016ac60c-c282-4859-b583-3f4e719dde48	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:09:43.114124+00
91423113-2d1e-42f8-b90c-fc3c81a39438	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:10:14.561851+00
3052b721-2283-4f4f-818d-336d75919a2a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:10:43.422326+00
f0a14350-f847-4644-8c70-2e86292b6d31	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:11:15.357585+00
3fd47657-d84a-4229-9308-a5b85e4b0eaf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:11:43.428729+00
5e5eb69e-3755-444f-9db3-d20a4365e449	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:12:14.859129+00
000362db-7a7e-45b2-adf0-dc643e9cefb7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:12:43.082652+00
f0ffa798-7507-4628-bf99-cebd69ce1789	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:13:13.809019+00
bc2464f4-0796-42fa-9e05-608fbc51cd6c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:13:42.947278+00
738517f5-e547-4b38-a5e2-5058857d81bc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:14:17.183831+00
10fdd2e2-e12c-4ea2-9c99-07a4b95580fa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:14:58.382396+00
4059e92d-cd3d-43be-8419-83604e9dfc9c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:15:30.443893+00
e85a3820-81b5-4dd1-8c44-2b63e827f566	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:15:58.252469+00
0d6917d3-f279-4fdc-9944-aff63ff9a065	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:16:40.854044+00
f0aa5e40-c2e1-49e9-9cdd-6cf101077345	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:17:14.40419+00
846d0fda-d022-4862-b971-0f55ecfe12d9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:17:46.456332+00
1f5882ae-74a7-4f10-be73-43412467ca0f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:18:30.947742+00
853fb9ec-4b49-413c-bc0e-f2ff5b9d726e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:19:13.477788+00
1cbfd233-1463-466e-8d67-9e05739f1806	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:19:43.040574+00
c36cd2ed-7fc5-4a25-9041-f4e1a553b051	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:20:14.142195+00
d699246e-303b-43ca-b02a-35d82f8a3139	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:20:43.082174+00
df8e6915-88a3-40a7-a7d9-4567caa0385f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:21:14.328767+00
0482417b-c932-4b3c-a4b7-5ebe0ff98438	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:21:42.405736+00
60a17e14-c31a-41fb-b134-9ccf8f6a1a0e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:22:14.196038+00
a101698c-ab4f-4a02-b58d-b69879dd3453	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:22:42.659068+00
b4e699bd-fc5e-4a1b-b09c-b57685d36353	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:23:16.707259+00
6ed083ad-6228-4030-969f-34266987e87c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:23:58.420734+00
880fd2fc-b374-4dbc-be4a-8f22d67c1f81	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:24:29.505873+00
a6f17e37-c884-4ebf-b724-1e1fcc158d16	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:24:56.557997+00
0fdd2ad1-57b9-43fa-bb6c-e788b69d121b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:25:38.635414+00
e7c23b25-0544-4420-9c2c-6265d70264aa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:26:17.266406+00
20218bca-9bca-4e6a-8006-7388ede20347	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:26:57.741636+00
7013d030-9eb3-4b5b-bb6b-cc80933e2a62	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:27:30.1925+00
892ccc74-b711-4e77-b515-a9b7484e808c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:28:19.199381+00
4f6faf7e-6577-43ee-9ab9-e50f90ca5108	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:28:58.46481+00
26498c2e-5453-4e54-8b17-a4710f5b5e74	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:29:29.708709+00
cf8710c9-073a-42e8-99b8-8030ddae81bc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:29:58.524055+00
ccebd664-743f-41a0-bace-2bead113e051	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:30:29.959677+00
ed49489d-eaa8-46a5-bff3-df3c8363084d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:30:56.575085+00
b4277e6c-f54e-4ea5-a722-13157d2f4fda	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:31:30.051049+00
f43b2393-5a1b-4334-9c7a-b78293a4ae10	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:31:57.776131+00
d21340f7-70be-4555-b011-59114e711d74	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:32:29.152809+00
0836eeaf-26bd-4ee0-9c34-bf917ff19851	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:32:57.808624+00
2a7b02b2-93f6-4bbb-983d-82d3bab24a7d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:33:30.716289+00
a84c3f89-4a0c-4980-8afe-3e0f914c926c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:34:24.054772+00
7b86ee39-869a-48b4-a03e-cd7d6deefa7c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:34:57.983744+00
83c63f4c-a251-474a-a2a0-252930673109	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:35:29.991667+00
88c43a35-7657-4f18-8f33-7e8bd9e5ecfa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:35:57.958467+00
cc5dd5a4-40de-4078-a2f8-4df1f9134b6b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:36:39.384324+00
c156b56b-572b-4951-ac97-b1c572987681	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:37:15.711264+00
bcef8557-2e09-4e51-a899-7ea8f9a63161	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:37:58.014729+00
4b316698-b7d3-493a-ace4-47335eff2584	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:38:31.362355+00
78a13cf0-fc32-455c-9fde-629742a1605e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:39:15.469548+00
2425f872-129f-4af0-a2fa-0db3a349c8bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:39:57.014135+00
5c2fa677-1c07-490c-bc33-3a6869945a1d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:40:42.654176+00
d984c386-4821-4671-b555-599dec00c324	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:41:13.565097+00
8c39e759-d11e-44dc-9ec4-b7cca46f24b8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:41:52.739129+00
eb98800d-c428-48e6-816f-ccccb9d4d8af	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:42:29.291659+00
3a2ae6d0-211d-4f93-abf4-380bb31f5c23	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:42:58.774141+00
257f78e1-4fa8-442b-9506-a766590585a0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:43:30.889337+00
bc3d550f-6a0c-443e-8639-73cc9f845534	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:44:14.810755+00
6c41dec0-7daf-437e-8f42-1142eb9ad4f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:44:53.599508+00
100c602d-84cf-405e-8902-c21170c5f8e8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:45:30.343323+00
87c7deb4-664e-41e0-9b7a-4316402b2b64	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:45:58.42143+00
95005ef3-7f35-4bce-a995-121febd0a9d8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:46:31.085194+00
20c70a76-f285-41be-9430-afc894a98827	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:47:15.166732+00
a50bcf5c-3a83-4e3a-a7e8-8d0814dd788a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:47:42.53794+00
38339994-a151-497e-8407-f5e2fa916e73	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:48:17.161568+00
63c380f9-ffe0-4ef4-a28c-28f5025618ca	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:49:00.84554+00
131f129f-9a1a-4fcc-a03e-126b37a69f67	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:49:44.995058+00
bbe776a9-1d05-4961-b9d0-a8d0f9ea5a71	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:50:15.043887+00
511d61da-db3c-4ee0-bc77-6c3ae9bfac99	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:50:43.762529+00
267e1efd-052e-4dd2-aee5-ee674a4bb339	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:51:17.839847+00
aa670365-d3cc-40ad-bb7a-30e7ceb4eccd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:51:58.509761+00
e99cc277-f281-4e1b-a462-4f687225dcf9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:52:30.454465+00
00beae4d-9e08-471a-86f7-7e8119024ad0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:52:58.730517+00
99e2d04e-6e9d-4002-9432-d0d622829bb0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:53:30.686868+00
905b95dd-3294-4388-9b46-3ce3f89f3228	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:54:14.210672+00
7be9b132-fece-45a7-aa8b-ede5bd218ad8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:54:43.008196+00
6795690d-543e-4fdc-a9eb-d4e81e82f5b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:55:13.960807+00
668c35e4-8ce9-4155-a33b-c7fa10465c92	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:55:42.558904+00
56d037c0-49eb-4981-a536-b9df1fbbbb7c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:56:16.261039+00
944e1792-59dc-47dd-a63d-1f2b06193192	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:56:57.552626+00
4278bbd6-b616-4aa2-83ba-7ba32341be1a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:57:29.604655+00
7b16c079-0796-4699-93cb-64dccea7f8f6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:57:57.491652+00
0a5b363f-1ac5-4efa-804f-e17ced8106b7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:58:30.022508+00
a243490a-05e5-4416-ad8e-0eaa9af2c2af	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:59:18.276821+00
57f567ba-8df6-406f-9ea5-28f0e7cd9cec	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 07:59:59.710992+00
fa5c23f3-62b2-420d-a090-a401632df203	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:00:29.590234+00
3dab9136-9105-4e13-8250-1a19d915452a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:00:56.666194+00
2126528f-7948-4b61-ab08-70a8d9ca395f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:01:30.182948+00
914899a2-b1d3-4108-b050-d027d8063840	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:02:16.654405+00
0a785f3d-79b6-47f2-9d94-de0050654f9e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:03:09.62757+00
e2421e03-2e1c-4f47-85ff-aab3cf36c2cd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:03:43.359285+00
6db95253-b4f8-4d34-8685-73f6c61c8df0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:04:16.747702+00
1a0209b2-0ba7-47f2-8c6f-3379923595b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:04:58.373073+00
8f9c8111-765a-494d-a2f3-bc9dbd1b7f8c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:05:30.095496+00
5210b47c-7c18-49c8-8a9f-210ebfcf7054	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:06:16.884124+00
dc3e39e3-1830-4d51-be00-83c932367d1c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:06:58.374953+00
c8a2c05a-5cb1-456b-89aa-e35225f2a275	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:07:30.045889+00
26670794-b31b-44d8-bbfe-a29efb93328f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:07:58.150967+00
70605109-246a-48c3-8a90-3d1572318771	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:08:30.418195+00
fbfb5d61-a057-402e-bd40-373599f71353	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:09:16.803096+00
d4763cad-d010-4a20-9c2b-0a14adb698b9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:09:58.834099+00
ab2c3cf9-3814-49c1-a297-069c66d1f255	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:10:43.661239+00
621d5190-95c7-4e36-856c-1e5ba9efef7b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:11:14.884075+00
772d0699-01cc-450b-968f-bedad44f8efe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:11:43.087041+00
03c6cad4-e759-4fc1-9494-5eab2fc1e79a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:12:14.664683+00
e11e5139-f436-499d-a348-14d4d3332425	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:12:43.160656+00
b564ed11-efdc-4452-b02e-be90e4ae5ceb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:13:14.667699+00
7115cc80-f07e-4589-8975-1a7430f51001	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:13:43.613953+00
2c5ff07e-41e4-4c92-8573-a4905a9a3a14	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:14:14.673726+00
53a20eb5-6054-48c1-af03-facfc42c253c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:14:42.539763+00
44ae2d90-d74e-491b-abae-5c6d4192c1ca	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:15:13.638948+00
4e64f31b-66ce-479b-bf21-fd6948d42342	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:15:42.766977+00
0cfac9a3-ad65-4aab-a92d-1f51ee6f5fff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:16:14.765174+00
683ad0c7-20ab-4b3a-ae42-d8d334bfa600	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:16:52.441603+00
611544bc-e72c-4512-83f8-d2d35f9b6efb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:17:30.834849+00
98a4fc53-75e4-4958-89b6-54c48ebace1b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:18:24.632539+00
35cf0824-ffc3-40dd-aa19-64789fc8f6ce	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:19:10.270549+00
81988a6d-7be1-4eaf-b1d5-dd164c138885	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:19:42.920366+00
03519f96-86b7-4356-a5a8-7ae11ce13400	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:20:17.094197+00
b38f6328-da13-4d5c-abf2-6cb01712f839	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:20:58.450033+00
68d8c43f-c350-4dfc-9d89-17b9f93af416	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:21:31.50151+00
d04ab690-0d02-4e4d-a250-3db00b857366	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:22:42.869334+00
dbf73d22-e6b5-4574-bf43-e571405da66c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:23:14.000032+00
8fcccfe9-0498-4883-bfa4-e5d28c6ceab6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:23:42.269252+00
46f6c99e-cae2-478c-bc56-d940485b51c7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:24:14.282525+00
7c87bc66-a32b-43f3-82ea-1a59df8403df	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:24:42.355418+00
92d75935-1d38-4b03-bded-aecda0d56c9f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:25:16.357066+00
6691d8c6-3bed-4c10-a278-9138648a9a28	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:25:57.537529+00
41359a18-7259-4625-bfb9-599094c517ee	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:26:29.643842+00
8a9595d7-e538-41e1-949e-29c9a0e109b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:27:08.995217+00
f12a2e61-99c6-458c-86e5-9b0ec007aaf5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:27:43.143286+00
d8d4b004-b0f7-49ac-ad4b-8d0dbd8912ff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:28:14.734779+00
0003c0b4-84be-4eb8-af87-7008af5d19bc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:28:51.866226+00
14bbe494-1fd4-48f8-86ff-fb3f15e67527	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:30:09.693706+00
c8e00b01-5801-4c4d-a1cd-86bd30bc6369	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:30:45.783572+00
2ea98b1d-5c51-4d8e-aabd-90ae5a5ebbff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:31:30.793382+00
1b1b1127-4983-4049-aa6c-c0d8368c8cd9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:32:14.200565+00
f7466345-a72e-4c4a-849c-f374164482b7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:32:42.241185+00
5213efc5-5ad2-49c8-a6bc-ab7ba0aa5f97	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:33:14.455473+00
53848963-809a-4410-a025-eea69eb57117	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:33:52.119937+00
0eeeb0a1-2187-4946-a68f-02b9856132a2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:34:30.111956+00
77316d4d-28ba-4153-b066-18153c760d04	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:35:16.568443+00
0603f2c1-34a3-4b88-bec7-eff6931ed4f6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:35:57.765934+00
5b13ff48-9017-4ade-9b93-164df90f9119	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:36:29.766459+00
c16acd41-fe56-4203-860a-fe60080010e9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:36:57.857637+00
a585674f-7bb5-4a42-b1a5-a336ba9a8e9d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:37:29.331787+00
69d6b1e8-f40d-4dc7-8761-c4b84d296f84	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:37:57.301462+00
3a4133ae-f5c0-44cd-92c9-564e3f20381f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:38:29.941965+00
b4d02aef-2837-414d-b58a-22de2fe26ab2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:38:57.544217+00
bcdea3d6-b75b-4788-a117-bc2e5ed44407	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:39:38.836762+00
008c8962-7389-4078-9b61-5e46ced432cc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:40:16.390135+00
bb9b5d38-9b40-4ea3-94b5-5a8c9947d020	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:41:02.816953+00
3be76644-4dfc-4a67-a7f3-98be36348755	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:41:43.362372+00
2c5fbbc8-ddfa-4bf9-8a7e-1b96575a0f70	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:42:23.686782+00
c7af665a-4dd7-4af4-b83d-3f7527d0580b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:43:09.203006+00
78c276ad-e794-4f65-8be5-37f5bf5c133d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:43:52.171877+00
9ad3913d-e229-4575-87b5-bd191894beb3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:44:30.270942+00
b417d26b-9234-4eae-a5fc-d0c0f4886994	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:45:17.003015+00
d4f8e9de-dc86-498d-a18e-49630b593ea2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:46:09.257338+00
47260b5f-b80c-489c-9084-f4b6c3ba8345	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:46:43.161204+00
210373c0-7ad8-4643-8336-692cea656fba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:47:16.78868+00
233e1d50-2d4d-4e34-b919-e30f8de509d0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:47:57.758454+00
5949c2d0-5ca4-461a-bd6a-acb738219c5e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:48:30.545262+00
66dd9b79-2529-4850-a909-ba6ece3a7026	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:49:15.246384+00
e4e296ac-7e9d-4e19-9760-8560167a104a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:49:43.70688+00
9e1f8a36-daa5-438c-b4bf-13fe30c9b068	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:50:17.374699+00
e73f5cea-afb2-46ec-a39a-6e62fd087f21	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:50:56.780288+00
2dc1b4ec-2eb7-4df2-9739-e1272b306f7c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:51:31.630521+00
8ffd04c5-578e-494d-a5ea-9a31cc8b472d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:52:17.775713+00
47b877e3-1be9-4646-a0a1-7761fedeff39	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:52:56.857138+00
c52c1fad-5fd0-4c51-b86d-2ee373e53947	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:53:29.971501+00
266adea3-638c-4b89-9e06-9e555464e61b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:53:57.851708+00
558c7294-c62f-459d-83cd-682c8f53f6b3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:54:29.839912+00
97f7aff2-d62a-431d-a21c-fffb42ff99b1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:54:56.738036+00
64ed3860-fb35-45da-a318-8d0a74392dd7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:55:28.79205+00
be9764e2-68d6-4aeb-8243-1bda085ea6b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:56:10.664954+00
fd437e8e-993a-4c8a-bc67-c9f13025a937	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:56:44.813463+00
a0e6e576-4fbb-4254-a4d6-79ef09e15fc3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:57:17.62345+00
639a328d-8cf0-44bd-8da1-e6a4b62ef611	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:57:59.774524+00
156bba35-ffad-4906-ad04-780806b95c8c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:58:39.283643+00
8ee009c3-f1a1-41f5-9914-44daf9a251b1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 08:59:17.417823+00
0496265e-fe51-46bc-8308-5f599891c68b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:00:09.308508+00
4d80d059-6045-4821-88d7-af587ea6f041	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:00:43.620686+00
180bd4c1-daa0-4558-a3d3-181038b767a6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:01:14.869152+00
ec21869f-4114-4bf0-b75f-4a2264fe206b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:01:45.278597+00
63954ec1-198d-455e-8e25-60d195e93628	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:02:17.053627+00
c7e1c818-44de-4d40-93b3-70322510422e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:02:57.216087+00
f7bea987-e0fc-4149-b546-9bd1b9029770	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:03:30.204381+00
2b46a7e0-aa83-4e99-8770-1a3e93345b40	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:03:58.090367+00
03f224e5-2292-4387-a2dd-25d259e863b5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:04:29.116432+00
3637dfc8-4588-49bc-baa2-99a9d6c3b225	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:04:59.181728+00
03741ae0-9611-4d77-8348-759c91dd003e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:05:30.311419+00
db51133b-9102-495f-ab38-29f3c3811b3f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:05:58.174804+00
3de03180-84e2-41b5-900a-acb54421d664	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:06:31.534217+00
dbd0739e-0de9-4037-a312-574786862a99	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:07:14.02025+00
a53c11dc-eec8-4e09-85c5-60a77b3241e4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:07:42.10342+00
b8816caf-fee6-4787-8207-723eded5ae4c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:08:12.800931+00
0efba61a-f23b-4f02-9da0-81601114f19c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:08:42.362565+00
0c545ea5-57cb-4e4f-85ec-4300a571c845	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:09:13.88511+00
c42e8c69-4495-4302-ac75-264cb6bd2998	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:09:43.736939+00
72ca3af7-b73a-4b28-a32b-72e8ce87e17d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:10:13.935909+00
dd50f52d-0f64-403c-9458-7ba61e219280	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:10:42.262514+00
a99c53f7-8e9e-478c-a9ec-160bf9a20c6d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:11:13.963683+00
7d07a6dc-a367-41a8-81f3-5a8887e51eaf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:11:43.737586+00
c80ad79f-fa52-468b-9e3b-2c3592eb2c33	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:12:18.596898+00
979a7c35-6e07-4240-986e-a942892ef78c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:12:58.787934+00
f93f8cc2-2da4-4ff9-830f-c249436dd351	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:13:30.218121+00
ccbb802b-3891-45c3-b307-8370e5fc2e33	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:14:16.660997+00
90ef78cc-3917-49cf-97ec-0adb3430e63e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:14:56.572875+00
5af7718e-312b-47de-b8c3-db01980cae2e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:15:30.005949+00
e5739161-3702-4ed6-9ba8-3dc9c1f1b7a2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:16:08.464681+00
9325e0bc-fe68-49cb-a7c1-62c272585fe7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:16:43.704411+00
3fae1df0-d377-4053-9436-386f8c42fdc2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:17:16.843482+00
264ed7f0-be11-47d7-b1d1-8922ffc8409e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:17:58.119989+00
27d42c61-49df-4761-8f3c-6f315f031274	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:18:29.582487+00
61cf8f7c-c4ba-4511-973c-470e729bcb13	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:18:58.088645+00
58a64ceb-e2e7-429f-b4fe-b4b1a947b5c0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:19:30.241054+00
7e27f820-ca22-4141-88bd-602b83b89bd9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:19:58.14399+00
905726aa-3263-4dfd-a453-a03b6d510664	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:20:29.930553+00
8e5fb924-f72e-4e3b-9ede-f59a05fbccff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:20:57.731109+00
f5e7146a-6ee0-4d68-b15f-3a0e2f17faf7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:21:29.608708+00
6ab2b9c5-c8a5-4d10-9ad6-46d9874648eb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:22:09.198188+00
3ecb6056-e5b3-458c-bcc6-e4b4b3989c6c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:22:45.506484+00
016e976c-88f6-4095-b414-43f3046475d1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:23:31.334021+00
6fa115d4-cb28-4773-8466-eee4c56d21cd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:24:17.124519+00
3fd305a8-b9e0-4f8b-ac70-c5fceb5a91ba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:25:14.540046+00
7fafdd9f-42e2-4f96-9cdb-73f32292c24b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:25:42.79756+00
a8c21b9e-910d-442e-995c-f570a003a98e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:26:17.078604+00
ba0a27c3-a023-44f0-8ea6-96c9aedc7292	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:27:10.9916+00
07ca4727-18b2-4b8d-939d-bf399392d323	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:27:43.790226+00
9a8c0598-377c-413a-a67f-6acb27746d89	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:28:14.547817+00
d0827589-3846-47f4-b913-b8a425e3c860	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:28:54.217648+00
822176e5-601a-4d17-bfe2-66f07be34679	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:29:29.995208+00
866b6a01-6c79-414e-8277-5ce16dd34f43	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:29:57.656728+00
e381aece-03d7-4068-8523-c942d7757642	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:30:30.176207+00
25e86e33-5066-4a6e-a923-54a93d94851b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:30:57.973246+00
29f78756-92ad-4e05-b979-ec7b567b48c1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:31:29.771189+00
0922aa0f-b6d5-484a-b5b3-f639b3c736e8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:31:56.849917+00
16eef549-ee82-4244-a83a-97e57ee6e281	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:32:45.269997+00
85975494-2efe-4771-8d1a-fbe6ed31439c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:33:16.498922+00
8e73f302-b307-4d71-9174-6a316a3490fd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:33:57.313589+00
decea64d-7a4f-41d6-b59c-bd8af63befcf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:34:40.028681+00
6c251b81-3d34-46db-8169-3611db1c1780	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:35:17.844902+00
6b891110-bf2f-4363-ae4c-9688923287c0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:35:57.02053+00
89257420-eb4f-4720-be4e-b14249df7bac	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:36:30.205631+00
ac8d13ec-6b2c-4401-88b7-2df61d607f12	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:36:57.722083+00
85397144-bba0-4539-aadd-ac181da2c855	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:37:30.488684+00
14930a7d-63b4-44bd-b50e-44745692040d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:38:15.231052+00
a04d8fe4-2d00-4a08-a35d-cdd89f146a73	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:38:43.167029+00
3196db7f-5033-431e-81d0-2d6bc73323bf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:39:14.48976+00
4d327559-fa19-4ef9-9e46-ab0c14c3a2ef	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:39:42.763549+00
6f1b919b-e48d-4d8a-bb8d-9a604518100a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:40:14.793012+00
2e80e80c-20da-44d4-8acb-a23c861772e9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:40:41.963694+00
94be446f-e736-4149-a9a5-7dbe720b23d7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:41:15.173278+00
257a9a01-d586-426b-807a-89b862ff74b8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:41:43.097025+00
bd7eaa73-56f3-4457-a7ce-6f9cacbd1dde	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:42:14.894023+00
4062f437-0ee6-4b79-9a2f-64c942d66d28	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:42:44.630581+00
8a55f4bc-f708-4707-a9c4-09ad5da53530	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:43:25.941868+00
316f327c-afd7-40c3-b94b-71fdcf28a0f0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:43:58.972685+00
89c28e01-12aa-4fc5-84ff-d09ad50c8d88	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:44:31.352197+00
575ae7a4-21c5-4a9d-ad80-9ffdd07d49bf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:45:16.974535+00
77418033-371f-4781-83cb-8f56b28f5194	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:45:58.604437+00
75cbb9b6-c5d3-4d08-a6c2-b8d65347d249	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:46:30.106956+00
f1e96a05-3d4e-4ca0-b4eb-e5f861d8f433	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:46:59.066472+00
4e289569-486c-415d-bd0f-7caf2f32e7fe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:47:29.025216+00
4c8ea7a5-074a-40e9-830c-137ddb33de88	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:47:58.538112+00
3bcbb49c-a9b4-4e4e-b466-d75ca2d41d97	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:48:30.167946+00
fc147968-b130-42dc-a0e9-3aef561c4acf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:48:57.997465+00
f5473d61-cab5-49c1-b59c-455159f7fcfc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:49:30.085726+00
a239ca9a-fcef-4f18-9380-d9f91a5557b2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:49:58.047193+00
c2f7b32b-f556-40d1-b0a8-8a86e7ba979a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:50:29.254489+00
0971bd31-3fb2-48f6-a85e-209587e8c3e0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:50:58.618562+00
e95d0933-6a23-46e3-8f11-77f9e4dba681	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:51:31.159131+00
1ed467a2-9195-4a74-895f-13f8435ad297	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:52:24.96313+00
28e82e25-17e2-42ec-8b8f-0ece678e57c4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:53:31.638245+00
0e68e45b-a7e5-44ee-9fbe-994587d370d7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:54:18.161288+00
410d90dc-72b1-415c-b9fe-4505934b3dc3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:54:57.970882+00
1a7f7f3f-dfd5-47bd-8ea0-6f36420c8e01	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:55:30.027082+00
e11a847a-59a7-456c-8203-b8f71284dcc9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:55:58.004942+00
edd98633-5b51-4af6-84ce-5b0e96018608	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:56:29.794187+00
5712d227-3ef9-4452-b845-fd50d641fd5f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:56:58.726097+00
03f3ec16-5f7b-412c-88c5-0c7313809d48	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:57:40.252134+00
62715f51-8de1-4376-9752-0731bb292410	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:58:14.786857+00
eb7de375-eb58-4824-9771-139a5b93a694	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:58:41.912214+00
b2265127-7089-43de-b35a-71eefed4e6bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:59:14.909466+00
2c8f3e73-f830-46ee-bf92-df471619529d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 09:59:42.820676+00
c2954ec5-6593-47aa-bf46-6beabd5562da	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:00:13.521024+00
8a921ddf-b46a-484e-accd-d880285c878b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:00:42.802042+00
a941112f-0aa7-4280-a969-23ce69b0bd43	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:01:14.802199+00
3d53cdb1-1339-487f-a344-a4a1d08c2c35	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:01:43.002318+00
f470c2c0-45ea-4d4b-b20f-d782f3534bc2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:02:14.588696+00
2af09478-35d1-43d7-90a9-cd17f60c9d17	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:02:43.016289+00
51a54159-bf58-4e78-a6e2-8b9a1ea2f4a7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:03:24.120288+00
b2ef8364-506a-4aa5-a5dd-e09c58c9f975	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:03:59.462213+00
2ea047f6-8c5b-4ed4-b01b-59acd75b730f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:04:41.627479+00
ba232f56-b7de-45de-afe1-b5e1213cba17	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:05:14.909501+00
4b6e6c20-f79b-416e-99cc-7e4a76f47cb9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:05:43.071053+00
9c5efa77-4fa9-4978-8246-dbdddbecc147	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:06:14.622738+00
cbcbdf13-fcd1-4a7a-bece-521e1e89d6fb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:06:43.581593+00
92c45494-c0cc-4eab-a1aa-874d377ab7fb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:07:17.265349+00
b2db4f4b-ec6c-4675-ae97-a61d69c52f89	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:07:58.550642+00
155ce451-f4d8-4faa-8b70-95093f5398f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:08:39.48109+00
a687d5ed-fd1a-4ee4-89f0-4b883599663b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:09:15.050791+00
df1f568c-9fbc-41d7-9228-9851d424b378	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:09:43.389124+00
4f574726-e824-4533-be09-07502973f159	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:10:14.758211+00
3dfe7225-37ce-4e01-a158-b53eb7856726	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:10:43.690706+00
a6656169-617b-4cd3-b223-3d9b1a34b1ee	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:11:15.626458+00
4aff0dc0-ac11-4796-9781-10cde22ef9ef	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:11:43.046573+00
83156457-8cf1-4131-898c-a22116766993	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:12:15.396041+00
631db21a-44f7-45e0-bf1f-29e35225e94d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:12:43.610498+00
2d2d3631-1608-45d6-b555-e2af9f310884	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:13:14.194449+00
8701838b-4340-497c-bb64-ace142463824	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:13:42.135646+00
f7be8c28-e50d-4ebf-b8d4-09e2293ffe40	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:14:18.31185+00
a7281b29-0d34-490a-9c44-9494d74c5586	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:14:58.28693+00
185c8c40-30aa-4285-8f78-4462f9fa260a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:15:29.303952+00
2d995927-21f2-4aa4-9dcf-d0b7643a1f38	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:15:57.124317+00
a7be0baf-e8d9-4b49-a668-9ba6c637f351	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:16:29.822982+00
74c27dbb-f22c-447c-83f9-7c2819676d77	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:17:14.367453+00
ec637607-9226-445a-b897-eafdf192d9f6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:17:41.450557+00
bab2d296-47ce-44ee-b860-3d85aef026e3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:18:14.027856+00
50d511d2-ed4c-43ba-a906-d8b9edac5422	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:18:42.282902+00
c1b6aeb9-76e7-4047-b47b-ce71078d7897	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:19:24.464992+00
edc76025-4183-4db4-a8a3-310dc6e5ce2c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:19:58.554981+00
d144dcab-a78c-422f-adf3-eb28d7f11e88	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:20:29.517369+00
1b2e55ea-152c-44af-b467-665abc42677d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:20:57.560916+00
5f1d8c7a-68ef-4b42-9ad7-07d9e08959e4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:21:29.907062+00
c0b01001-746b-4d5d-846c-9812185a1c64	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:22:08.72264+00
1df05e12-b7f3-41ef-ad09-b25fd0aeb4a1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:22:42.571324+00
7ee84935-6e58-40f4-84f0-6ba94f73d32c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:23:23.450925+00
fee56294-68e6-4c31-9e85-8b58ebfb46d2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:23:57.652717+00
225fb38c-4863-42d8-b268-d05b492b4622	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:24:41.336748+00
e12b8ff4-0b24-4332-b5f7-aa3fa700a53a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:25:23.355193+00
c4e429dc-4be7-4391-8676-06c7c0b512c8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:25:57.783471+00
e3b49da9-9cb5-4a09-b6c1-b5a9403dcb9d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:26:29.607964+00
b3a100a4-bf4b-4daf-ac08-acb4fa8bce01	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:26:58.033751+00
3c5d9a19-26e3-4698-9a3d-e971c0a6519b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:27:29.63401+00
64991a34-9c18-48f7-8001-1e087d90e379	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:27:57.828802+00
01f3c95d-41ad-4182-8c16-9a0ffd866bc9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:28:31.019336+00
76a1bf30-b3d4-4440-9d94-0961a572a5ba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:29:17.666621+00
e5e34004-f9f4-42d5-8200-043ee96d0f41	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:30:10.556823+00
7f023e7b-0fca-44fc-bf5d-7627a6b28282	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:30:42.813471+00
092d89db-1abf-4ec1-b113-90938470e9e6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:31:14.562703+00
849c4af3-d4cc-48f7-a987-909190d77179	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:31:43.36299+00
797ed8e4-ac93-4583-acec-106059515f51	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:32:16.736822+00
76d17a1e-9d8d-4a34-b2b5-98a0c80c302b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:32:58.836114+00
395c28d9-2d5d-48c5-8a38-4517a2754bbb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:33:30.078778+00
bfca0888-5c4b-4e81-bee9-95ff94568f73	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:33:58.23104+00
d660fe6f-e800-498d-bf5c-a6d68b5d32f8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:34:29.775737+00
ef1e85e8-ea6a-49a3-a45b-bccf785cdd68	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:35:03.272463+00
3a1550c6-91f1-4558-89a8-ddc744703e6d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:35:43.758598+00
1c4d4fe3-6482-4ddf-9bcb-2af6cf8e1f3f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:36:14.609121+00
e6d49925-729e-4e7f-a83f-65e474155055	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:36:43.434815+00
d317c5c4-e929-47a5-b401-9428deec3f33	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:37:24.362201+00
652b48ac-c543-4222-b79e-f1b3b8c5db7c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:37:58.857589+00
090eb8e2-76f0-42bd-9e4f-f044874eaaed	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:38:30.23206+00
df686136-ed49-4dfd-b84f-d10f6d171552	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:38:58.275189+00
7b1f3637-93fd-42b3-ae09-f61c38afb903	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:39:40.748777+00
ce5583dd-c459-4d75-9514-2a4bcde544e1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:40:17.73929+00
26ca6335-6761-4d97-a5db-6171c5c68f3c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:40:58.505068+00
fbfcbe12-1434-419f-85c0-1668962fca60	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:41:30.498953+00
2803f204-2bc0-4197-b0ad-65d259689110	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:41:58.073186+00
a8668c68-8ad0-4ac5-bcfd-ff61285291c9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:42:40.530413+00
06de34b7-680c-4189-91ab-ae0f2add9b91	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:43:17.771354+00
00455eb3-2225-493e-8b98-581511237614	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:43:58.182092+00
efc0a7de-b3c2-4f91-85b7-2392c09f27f8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:44:30.044872+00
0099e483-6f3a-4d8e-8c4d-a8943523c623	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:44:58.190808+00
84f2fb7e-f733-4339-86fd-baafc4e377ff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:45:32.92787+00
cd410910-4b2f-4f12-b318-cec6d97eac9d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:46:16.946182+00
c7fcdf8c-e57f-4ba3-bed2-2b910ed25b6a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:47:29.32308+00
26f3a7b7-61d5-4259-b3b0-b171a5bcc4ab	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:48:08.325142+00
627d9a8c-4886-4361-84d8-962fc30fefbf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:48:42.866811+00
b75753a5-72a4-4f0f-ad2b-7ce29c1e2e0d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:49:14.111067+00
bf016140-6c0f-4c4b-84e5-f31c913ee7b9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:49:42.450817+00
5f8dc0a8-a7be-49b8-840f-4c5b3ecb3bd9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:50:16.722187+00
a3eb37f4-9438-46b7-9d2d-49a32516ccb0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:50:58.123191+00
6f046afe-0a1b-402f-a427-0a6d9ca1dc8e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:51:32.223604+00
98a7c079-a6e7-4e8d-ae1f-9f322ffd81d2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:52:14.344074+00
ef1c9560-de8d-403d-b3de-251d135cc774	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:52:42.560986+00
056801f6-edba-44c9-a5d3-572bebc893dd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:53:14.203033+00
b35425f4-2a6e-45ad-854c-28f5e753d7b6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:53:41.705197+00
f2b4fd2c-b6a1-4201-9e8a-44aae5215b5b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:54:14.393998+00
017fdc99-ffea-4ce2-a486-8dc9144e2b33	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:55:04.027956+00
eeca89f8-ab21-4fd2-badd-b88a5cd1ec3b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:55:55.829013+00
589efa02-23c2-48e5-8f04-714876d1bff7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:56:30.262152+00
2c5eead7-ea7e-43f7-ba1b-d5ab29a20bba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:57:13.694637+00
43697d4b-d590-4a6c-b969-4c058b582a36	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:57:52.919285+00
81054599-5a76-4063-8a11-f5b96b624f4f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:58:29.308857+00
93845aaa-efc7-4201-9b0f-aa9102a81a7e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:59:09.691632+00
550e65df-38a8-4a63-9d92-0cb1835cabfe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 10:59:43.162938+00
964982dd-cd9d-41de-8077-6a23210a48c2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:00:14.756175+00
1bb7148d-d4d5-47c0-8f49-33a185e2d9c4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:00:43.450173+00
b7438568-2a5a-488e-a61d-5ba5022502ae	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:01:24.880121+00
3b4744c0-86cb-443a-b628-3a528e8d23cd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:01:59.154952+00
c5cc0d52-a38b-4a6a-a222-4f39d75d95a2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:02:30.735255+00
206c58de-6565-44e6-bc0c-988305060e45	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:03:16.359075+00
f0bd5f5d-49e4-4988-86ae-58f0290f31e2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:03:57.94072+00
50eaaf2a-40cc-4c00-8cd2-c29a1f5db7f6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:04:29.975594+00
6327fcf6-5b14-4e36-9c5e-6bdcc928ddda	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:05:09.729547+00
e6799d70-e21d-449f-96bb-f0f1153b3f1d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:05:43.514948+00
9ef70b09-6165-440f-959d-915d0d3d6727	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:06:16.69683+00
6317983a-7aca-4156-8773-78842c9ee961	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:06:58.671667+00
cacc75f2-a9a3-4e05-aea7-cbb63cc38dea	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:07:30.097915+00
04d551b5-8b67-4148-bf78-8a57ea373020	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:08:09.176215+00
090e4914-5695-4f38-8a83-cc7db2bd5761	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:08:43.492981+00
d574d596-3c49-4812-8c15-f86cca382a03	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:09:17.191413+00
1a4d462b-a7c8-4798-8a29-4cfb9ebba3be	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:09:58.196048+00
61c0a7ed-cb62-4173-9351-1f59955c52cd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:10:39.392145+00
456d7415-2a91-45b9-b73b-26f6ef7ea5aa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:11:17.611347+00
d31bf1b8-2a30-4ec6-bddd-eec37b221d8c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:11:58.646823+00
8a027165-77bb-4f7f-b525-08d45ae5d63b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:12:30.522033+00
53ced05e-d0ed-480f-8293-603100dd058e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:13:15.174389+00
c26b2ebc-4757-45a0-943a-39f2ba9f23f8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:13:43.232181+00
dba1a5d1-c285-4eda-86f0-ba64f09e91a0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:14:27.112504+00
9aba0eb9-4823-408b-8678-1486782d95b2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:15:00.097974+00
50c6a494-0236-4f32-b703-01286d787294	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:15:30.269116+00
0e5a780f-8c49-47f3-bb3f-0196f1238552	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:16:14.04675+00
33487d04-a67e-4d3d-aa45-00a67660a5de	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:16:42.76319+00
5fd13c52-04d9-4739-950d-36c586b939e6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:17:16.572767+00
e81b421d-3801-4cd5-83b7-528b759ad9a0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:17:57.896066+00
fd5e4d36-63ef-4391-afd9-f57e04f97e96	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:18:28.291756+00
e1420582-c334-407f-a072-e12b1cef2808	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:18:57.670188+00
29443d0d-58e9-4f79-8762-96dffd20baa4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:19:29.525312+00
0dc329b4-707b-44ec-a03d-45cde0c54dc3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:20:09.450796+00
3ac7a8ef-de14-4e7b-ab93-7e1b5e3b4315	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:20:42.499867+00
e16f613d-885c-454d-b36b-2444bdc0cc5e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:21:14.087704+00
2f2310e0-6476-459a-8804-3a0cc9583a77	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:21:43.29658+00
e35ce987-7117-4b36-9b79-a6f6a015dcc2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:22:23.402194+00
163aa816-fd0c-4166-8471-fe8304ff96cc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:22:57.840776+00
1511390b-ae9c-40c6-b9d9-fa8148a94b7a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:23:28.371553+00
862d2631-f040-4d7c-8c34-1e743e60d0a1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:23:57.400379+00
72bba855-9173-42df-8932-aff60284f885	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:24:32.070849+00
e843aed8-2c35-4f98-a03a-5cf9fe4af63a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:25:16.756109+00
3239d6d1-7176-4ae6-a199-4eaad7d1e2ed	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:25:57.599542+00
c8addfc7-86eb-41a3-932f-29e9404d8013	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:26:29.494063+00
679d8998-f199-4354-851d-cb3a78f5b5bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:26:57.629192+00
a26e4b91-8ddb-48a4-983d-3989ef5b5e16	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:27:30.416409+00
ca2ee6a2-a4ad-4820-acb9-59438598f676	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:28:14.848543+00
1bfd333a-8ef0-47fe-bb79-2308d1d421cf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:28:42.613586+00
0ef1514e-3713-46f4-9cd9-3000d364af21	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:29:23.726731+00
8ebe7fc1-9dd8-4882-b24b-ffa1a496da72	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:30:08.281955+00
e20495af-49b9-4d6b-a123-1ec4e66fcaea	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:30:44.556113+00
6440b27a-fad5-4df6-bb2e-a5ec8bbc36ba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:31:14.500475+00
540f2697-0c8e-43ef-a0b2-d44c3a3acf19	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:31:43.070524+00
9ccb5183-2007-4fea-b652-0f1266a28140	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:32:15.164939+00
c0ee710e-56e6-4a35-9272-06187a4e8965	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:32:41.728289+00
c7b7514e-2930-4f2d-b91b-b83045c34444	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:33:14.620193+00
670f1d8f-cf3c-4bd4-9562-c271ee29d6d2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:33:43.780761+00
565dbe49-0de9-4954-8bb7-9c0a8d9733fc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:34:14.309192+00
27f53192-36ba-4d97-b24e-c56db2b74898	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:34:44.554184+00
6f03e84c-c977-491e-a414-7308e97174fe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:35:16.855535+00
40b603e6-d5ca-4a84-844b-9702dd538a05	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:35:58.347151+00
ee526568-9ed3-4d7e-9487-1a5837bc2e42	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:36:29.722331+00
efb10ec7-8b77-4863-a9f6-2c5330a5e8f1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:36:57.956667+00
694f5ea7-c431-441f-b67f-ae4dfbffccce	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:37:29.646584+00
6dc38927-7af4-46a4-b5a6-b77ab4d70c0a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:37:58.032035+00
d352d031-d5b1-440d-9b5b-b1921c214e5d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:38:30.728812+00
7855daf4-b543-4797-9703-13a06113a327	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:39:14.642622+00
021113d5-4980-4af0-a531-e6eaec0e7c8c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:39:52.712585+00
f05b7e03-9d52-4510-817a-bd3c95050187	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:40:29.087187+00
f9c760f7-f115-47b7-a9e7-e8538d9afe92	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:40:58.053445+00
24639d5d-76f1-41a9-a808-ae704a5fe28e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:41:40.454862+00
a3675388-a368-4dbb-9b2e-a6058bce8c97	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:42:14.839605+00
cefe73cb-2533-4a3e-8823-1bd21b74ba03	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:42:43.3921+00
65fe38c9-92df-41c9-bd7d-d15e3fef5da2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:43:23.890563+00
17c059f4-f26d-4048-9c9b-144cb152fd86	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:43:59.679298+00
54dbb391-65d5-4893-bcad-6d2b0303899e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:44:31.270687+00
f50d261a-5245-45d3-b22f-cb0a610d7a56	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:45:26.532514+00
1d68fd2e-492f-47e6-b9b1-3fceb9cd8476	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:45:58.998219+00
4d66e1dc-5d34-4429-91b0-2ade5648bb6c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:46:31.689244+00
78429163-1a3f-479e-be42-bec62d1cc986	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:47:17.642056+00
1c2af7c3-534c-4bb6-98bd-19aeba288cab	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:47:58.089693+00
1600b955-f0c1-45fa-9609-e47de0f6bfe4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:48:30.701549+00
6b9abadc-18fe-4cb8-82db-cdaae763240f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:49:17.873982+00
61b648b1-a409-492e-b329-9352def9d6d0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:49:58.584507+00
5425b06f-ea13-4d04-850e-a06c8a0c5e02	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:50:40.805082+00
eed746b3-b04e-48d6-9d4d-37bc6d816595	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:51:15.002296+00
ec625ee3-2851-42bb-83a7-89bb5a1d954d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:51:43.53584+00
35704354-0438-4279-b993-fc7808bed4d1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:52:13.955205+00
439f26c1-5680-4bbd-9167-943bcb1e20b8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:52:43.034554+00
9d8890c5-e9fe-4905-9910-93f5edd45a24	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:53:14.789273+00
02307943-01b0-4505-888e-0ad93a9a047a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:53:42.121124+00
76aa3836-c0d5-4120-af89-7a9fb5c09574	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:54:13.802183+00
982b1e89-6195-4b06-bffe-9da3d2e4ed9f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:54:42.261087+00
ade369a7-86c2-4695-acae-67a051f76fff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:55:23.458929+00
51886793-fdd2-45e2-9436-bdbb66d0af7e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:55:59.435477+00
64d38511-2403-4821-bbbb-afe028e20489	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:56:30.190139+00
b6d4a050-ec4b-4cae-84b0-56c60e8915b5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:57:16.810646+00
5880ff72-78c9-4a30-bdc3-19484ab2a461	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:57:57.408299+00
d71bd6e3-b079-4d1f-813a-4b23f8b95883	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:58:29.347978+00
fc16749c-701e-4a9f-b044-22bef81f9759	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:58:56.394414+00
c9138a54-8690-45fb-8503-474e9965469a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:59:29.230942+00
79f81a13-e620-4b21-be99-3c81bc5e6812	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 11:59:57.13924+00
6ef0ba97-55d2-4ccb-8685-8e1a1c2e8c57	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:00:29.488857+00
9c62cac3-cead-414a-8b24-6f91340288f6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:00:58.704195+00
40c7b007-7f84-4a5a-b5cd-c80f90ed0831	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:01:31.360385+00
aa333389-938a-44b9-bdd8-d8e3b2b4ccb5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:02:14.294771+00
be5237a2-ecae-4088-bb56-58406ea0cf91	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:02:42.364506+00
5f458691-9421-456a-a129-0161365103b1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:03:14.563757+00
460f6dea-8cdc-401c-874f-d14986b5a0fd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:03:51.973096+00
7a681cc4-46e1-4039-94b7-110ba6d7deba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:04:29.722133+00
dabcd2c0-dc5f-46fe-ac89-c97f882dffbe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:04:58.035503+00
ed0aeb03-5e0e-49be-aa92-ead57f8b9b53	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:05:38.33043+00
a7b410c0-5d29-423c-8ab1-40f919caf684	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:06:19.113081+00
9bb8e157-af27-4ea4-a320-79c72a08a5df	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:06:59.886983+00
86f938fb-9bc8-4a8e-954f-fce7166a069e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:07:30.382684+00
3f436c4c-447f-4c6f-96cf-c7c31f4e6859	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:08:24.295011+00
b8e48f94-3835-4043-9230-604a9744c31d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:08:58.154893+00
7354449f-51ec-4f72-912e-bafa937aeda2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:09:30.039365+00
19e7e1e1-3b3e-4506-983e-7c2e6f9e7026	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:09:57.488569+00
10b3a5c8-c83b-410e-abd6-c7dd81e19da3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:10:29.609445+00
2721ed77-10ec-4f59-a63c-32059398357f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:10:57.702429+00
1baff6ac-08ac-4ec8-a6ce-be7bad3653e5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:11:29.660744+00
dadf9402-be7d-47b1-9737-afb311a09395	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:11:57.889785+00
444f2e8a-0f9c-4375-828f-a528ea69f3a8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:12:29.684854+00
74d676b5-3209-449c-a122-ed0fe71720fb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:12:57.687706+00
85ac864d-267c-4bd4-a697-5a43d41f714c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:13:30.572305+00
98fb8911-f897-4422-ac02-e07a95c212e9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:14:17.428589+00
75164155-0a28-4a65-89c8-23347ce6134f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:14:57.937882+00
c78dc733-313c-4965-97dd-bfd596b1a689	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:15:29.960637+00
027188c9-f80d-40ac-b304-fe9301f0b216	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:15:59.023043+00
bd7e2ce0-8597-4a17-924f-79942b079245	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:16:31.743831+00
a9c5017b-38c9-4815-a010-c8e7d067f6dc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:17:17.222535+00
003c859d-84f2-4ce6-aa8c-385b5bdf8831	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:17:58.470139+00
88d7b461-cf63-485f-ac64-cae832ef9dbf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:18:29.795601+00
824fb3b7-967e-4f90-a22f-de8cf0163a56	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:18:57.938976+00
67144d72-ac0f-435a-b1fa-7775e762c5cd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:19:30.82911+00
a6a1c3bd-66b8-4c4e-ae3c-d735aa263def	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:20:14.635808+00
ead78c1f-9767-4770-96b3-3e10b4f42539	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:20:43.346367+00
06f04ca2-8ca9-4252-82bb-d7392c9ee919	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:21:23.940982+00
daf20dd6-730a-4284-bf69-edfe0fb94389	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:21:59.012656+00
e996c5a8-2beb-469f-93a8-7cb7a4f578f9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:22:29.921022+00
78fbb181-8a67-4754-8928-810144d11ca3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:22:58.10703+00
e0356779-8b0d-4293-ae4c-796a8da06e90	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:23:30.940145+00
a24b1667-8c4a-4153-81dd-4791a8e13eaf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:24:14.784813+00
b041d6f0-5d22-4038-8d26-2f17997b91db	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:24:43.55498+00
a5b0e5a8-da0f-49e8-b06d-9402aea91f6e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:25:14.666944+00
bce02395-8519-4065-88ae-ebbc5e665c4d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:25:42.904061+00
3ff6c364-bb1c-4daf-91d7-64418697e786	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:26:18.252665+00
b781d72f-7575-4f4f-a143-810f823600c5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:27:12.268996+00
f719fdb8-c901-45b1-a760-c86eb3b34792	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:27:43.381258+00
ffce54ad-2a42-44e1-bc06-14b163f41662	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:28:17.151843+00
b44c7848-d0fa-463b-a3b9-270b8cfe9be7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:28:58.700757+00
3062851f-6973-4b01-a4c5-cc1a3f041fcf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:29:30.052912+00
6c97ed81-1597-4589-9739-1f0b3194c6dc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:29:58.232559+00
ce47d172-ce81-4be1-b639-547c43abbf53	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:30:30.746914+00
fc8f8e34-ea9e-4202-bda2-0ccb16b2ebd2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:31:14.441058+00
c609a2bf-7ef2-44c0-9d05-4ace34915a4b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:31:42.296011+00
a142427c-17fd-429f-ab7d-1268bc65b989	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:32:13.817633+00
95ea34b9-e88f-4e66-bbc6-97bc2c621aad	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:32:42.136831+00
959b0856-87df-4caa-9845-34be950ae8b4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:33:16.350914+00
57bafdc8-2a29-4320-be94-b77f4a4ece4b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:33:57.468425+00
763b53f0-32c2-4cdc-afa4-e86cc7c9e8a2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:34:30.683453+00
d1f68639-177c-444d-8aa9-10c911d07d55	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:35:16.285667+00
1e997a30-03ab-40c9-b9c0-0a43ab987532	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:35:58.607511+00
22b702fd-1d9b-4182-85ad-2455328045e2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:36:29.64742+00
28888c08-5888-4986-be75-416fdc9fd9e2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:36:57.436647+00
f66b21ea-51e0-43f9-b1ba-e233d4bc1883	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:37:32.916644+00
62a033c6-6ea6-4fb2-ab15-f920b0b9fcd0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:38:24.091123+00
2213ce32-9f8d-424d-b7d9-7aaa94c1741e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:38:57.641285+00
bb70d7a7-a794-4ec0-8443-268a5a4d2812	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:39:29.675023+00
29b9a8f8-c02f-4cf2-81c2-0fc1e27453c5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:39:57.508778+00
b3be593e-d2b6-42e7-a49a-8b7efc814326	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:40:29.504637+00
bf84afc3-23bf-4a20-8ec5-188571142a5d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:40:57.671052+00
bd55e152-509d-4c71-bc79-de38f6e5d501	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:41:29.585708+00
85c53f1b-cf2b-4d16-9907-f5b33cf74a3f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:42:09.179004+00
6d89ba5c-fae4-4dec-89f8-ff08a0b6608b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:42:42.944522+00
ffcd5998-e948-4d93-80c8-6c2d4258e69c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:43:16.604562+00
20704a33-93f2-4be1-a3eb-3af3b0e10511	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:43:57.76476+00
109d4d8b-e761-4629-8b1d-d30c7d4f68a9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:44:29.816683+00
a08baf17-e07c-43ca-a082-bd0c439db192	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:44:57.818359+00
65b6fa27-11ce-40ae-af0c-fcf0409a5c30	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:45:29.7868+00
2065e098-191d-4cdf-a6a6-70684f2444b9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:45:57.68252+00
f96d278e-be12-47d7-a4e0-c68248b162cb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:46:30.088666+00
a31b2917-3d48-4418-a5af-b5280ff51491	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:46:58.054431+00
4a9b20be-f964-476a-8208-4eda10d8e9b6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:47:29.627469+00
9eea302f-f09d-4b33-8103-7eb44b9af1ba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:47:59.501436+00
11113ab4-4dc0-461e-a252-9d4501a3e21a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:48:39.555814+00
a8599fd3-1b04-45b3-8cfa-da776a7e86e6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:49:14.652665+00
254539aa-3269-48bd-b5f2-faef8ed10848	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:49:43.225304+00
fcc38e62-6837-46ac-9306-1df22070ec79	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:50:14.75191+00
9aaa0279-450b-47b1-8852-ea29dfb30a26	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:50:43.16671+00
6fe3861e-5c9a-4d26-aa30-373138c2acd8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:51:14.501713+00
84c3e2bf-8ff3-409a-b44a-3c29736760b9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:51:52.081002+00
e1559433-36d3-481e-8117-f43b5bcd5e60	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:52:30.011796+00
808cd985-7e65-4fe5-9b6b-211b20eceecd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:52:57.845618+00
809f6011-c728-4c7b-887a-f4eafb6fb6bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:53:29.790732+00
518f919d-f60b-4a68-87d9-8f6a04f52c8b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:53:57.864406+00
0f956104-961d-4aa6-b02d-ff659c7601cd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:54:39.596507+00
41f6bfa7-bd07-44f8-ad0c-a85f5e0a31e0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:55:17.120288+00
1b4009dc-816f-4002-84b1-e54df34c795b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:55:58.046989+00
2b1f2fd8-7515-42d7-a739-e0b3bd88195b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:56:32.678376+00
aed401fd-67db-4575-8d72-b6ef42e6e266	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:57:15.426258+00
83eba763-4453-4bf3-aaac-68e13e11c89f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:57:43.886898+00
20ef97cc-ebf0-4e6e-a233-081e0bfc34fa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:58:17.035201+00
b05b530f-980b-4912-abb8-baaa3f226f8f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:58:57.614362+00
937a66e3-3272-4e52-9019-32f525493fc5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:59:30.218933+00
02f97d5d-85fd-4471-87bc-8f4590e0fdc5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 12:59:57.920261+00
c1990a09-343d-4b07-a2d4-855b0ca407f8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:00:30.579457+00
ec072736-da39-46ef-b543-32d72e2e3a04	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:01:16.299477+00
beb205c9-f34a-49af-af3b-7115df480e73	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:01:57.271291+00
64ba07aa-8df8-400d-9d33-3085d5bfdfe2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:02:30.179214+00
e82ac1ff-61bb-4e24-b52a-092927e9af27	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:03:14.452707+00
b6c97f71-edc5-47f7-ab79-b63bb5de68dc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:03:42.345311+00
217f1fb9-54c9-4551-9039-cb40b5e29355	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:04:13.816536+00
a7b8ab0a-e445-43b2-8eca-396af7ec0f6f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:04:42.391477+00
60185c43-f052-43a2-8a4d-afe7a6bb7577	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:05:13.992346+00
c9d7591f-8be4-4c63-a07d-2c91287c2d08	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:05:42.376013+00
ad8faec5-930f-4a8b-970f-6fb5212403fd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:06:13.921725+00
7205bf1f-2b27-47f0-8772-6d10d300faa4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:06:42.851343+00
a00e7e3b-3ea6-48e8-b3b9-25329bc64ae7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:07:14.071456+00
48537964-00f5-4301-a02f-6942623c8b7f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:07:42.28288+00
2f06041e-396f-4065-91f6-f558bf5cbc79	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:08:13.961191+00
21e30320-153f-4bd0-9d02-10daa1cafc4b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:08:44.447587+00
8d5c3bc5-c4ea-4453-8a02-403788e07242	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:09:16.453024+00
e5353d26-7d15-4063-b457-33cebf1f07ba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:09:57.683763+00
4c558a59-7df5-4fd5-91c4-2458c745a7d5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:10:31.909023+00
74f90209-8281-4040-9b17-d90f424b02b7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:11:25.115583+00
294d575c-5ccb-4290-890a-d622955034cb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:11:57.714053+00
e6990984-8dab-4873-ad42-9bf2eaf21db3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:12:29.588968+00
584bc47e-baa6-43f9-9f53-18e53fdda537	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:12:58.736192+00
e8cef17e-fe23-4813-84f1-bcacfb9daa46	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:13:28.508226+00
a04ed28e-1eb1-43e7-9ada-b985abcbd937	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:13:57.224054+00
5ef69cf2-720f-4b92-a23e-9e5e0e8d8f92	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:14:29.599191+00
5b8507c0-417a-4057-8fa4-034a0fc45984	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:14:58.194567+00
585df244-1020-4724-8502-c02187f1341d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:15:30.399628+00
95d93d9c-f3e7-4fd6-a8c6-0a9eef86c334	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:16:14.471794+00
f9981f2f-78a9-4cbd-940c-4b88a1961458	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:16:43.105461+00
65eacb85-300b-4cde-8112-79ce4247b9aa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:17:14.348587+00
3f21a944-c156-4623-aa04-2db6af7fc2e8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:17:42.789599+00
8d461e09-7aec-4725-bfe8-dfa4c07d7d28	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:18:14.22961+00
70cd049f-d2d7-4d60-8c6b-39f2c5bf43ad	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:18:56.13087+00
b20dc6c4-8b4d-4872-b26b-4962e8e408c2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:19:30.366297+00
8ad7d25b-222a-473f-bf78-373e1df07f1a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:19:57.642688+00
e6ae6b21-338d-4f22-b8f2-6c8b86a0d361	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:20:30.380236+00
6ef672ec-b560-4c21-a765-52a1daaccd52	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:20:58.090882+00
f0a4c1ff-1980-431c-be97-6f3ec5ce0b7b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:21:39.22684+00
37d8daf1-d04b-4e25-b01c-abce139051f5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:22:14.712401+00
78c58223-2a02-4cd6-8ff2-1514db733c9c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:22:44.251319+00
6761960a-7969-46dd-869b-ade093a0bf12	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:23:14.504189+00
d34173d4-89b4-40e2-86df-04ddcbbd5517	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:23:43.810475+00
e32fffcc-dc95-4668-adbb-d295ca6a46ba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:24:17.234676+00
08cd94fe-25ea-4f06-a186-036d319856a0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:24:58.59118+00
fdbc39b7-27cc-466e-8472-ec6cb5782c40	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:25:31.098497+00
1de3dd9c-faff-4eaf-8e0e-812de14c765c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:26:14.782971+00
c1e3e419-3708-4ce3-83d7-f49beadaaaa5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:26:42.85395+00
4e7ed020-bee5-4930-9d49-e38663b955bc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:27:24.210481+00
8761e2bb-4506-4479-a1eb-efd6d12d5797	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:27:58.140561+00
22f005f4-98e6-44f7-b931-401ac4e9006d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:28:30.014741+00
34c7546f-3db2-4dfd-a8f5-c5b17f83655c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:29:00.895409+00
de664b33-fb17-473f-8c0c-4e775e15cb5a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:29:43.62955+00
df1ce8f0-5d0b-4531-a5ce-c0ceecdba3f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:30:14.651518+00
2c79523e-21cf-4a9a-bf07-3f1a0b061373	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:30:44.446514+00
3011e95c-6af7-40ab-8407-dfcbc7695f14	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:31:13.737643+00
85744098-6cd6-4914-b3f6-11b0088544da	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:31:43.807339+00
9d4f01fe-260d-46c4-b50f-9ff78ca3b88b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:32:23.204823+00
b339fb26-10ad-4553-a4a1-d54c908fce6d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:32:56.708535+00
872faf6d-84ef-4525-a77f-c3b5bec38a0e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:33:29.135806+00
7010b060-6ce9-426d-a651-c42204d974c2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:33:57.682973+00
3249b871-8174-4f9a-a4e2-00e6de550eab	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:34:29.166966+00
78ae0afd-e9ba-410a-b84a-eda823e18f11	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:35:08.610042+00
b39c54fb-a258-4084-9821-bb1ae1b365d0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:35:42.939973+00
75cd8cbe-9018-4f72-a786-20805199aa9d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:36:14.127486+00
dd93ee0b-47b8-47d2-a575-89a619d794d4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:36:42.404785+00
fe28c8f3-97a3-4893-a1db-97a688755930	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:37:16.493332+00
a55e23db-4d1f-4c4a-a194-320470ac0406	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:38:10.709273+00
7f94b9b7-01f7-4818-a432-27630b89a193	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:38:52.991677+00
ebd7b39c-e0af-4ba8-8643-04850d12a707	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:39:31.95111+00
fe3c23cc-3eda-4547-8640-fd26ea632217	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:40:17.580425+00
af52fa3b-62f8-4174-863a-7fce7df00994	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:40:57.725889+00
08257085-4e8c-4997-9623-4e3495b39099	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:41:29.494685+00
b8393b41-3439-4840-97ae-3a1490d5afaf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:41:57.480527+00
21c6b835-28fe-4200-9df7-f4ece6f05223	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:42:28.264262+00
46ca0992-efee-41ab-90ef-30218ba13a3b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:42:57.852851+00
73cfdfac-d6ce-4869-a4b7-b119bb12e2e9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:43:29.700883+00
9b30a705-813a-4353-b1fc-563e3fa60fc2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:44:17.370882+00
faf0d0b3-5703-44ee-b0fc-72181605e924	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:44:58.355922+00
b7c01112-77d0-4896-9262-71194726f83d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:45:41.635267+00
5a214bc0-335d-4d5e-84d7-84314cdc4dee	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:46:24.829187+00
994b1835-2f9c-4af0-a84c-93df457985d5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:46:57.848019+00
c3c477e7-63dd-42a3-9308-e8c62582c034	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:47:39.291976+00
5a8e5613-1720-42fe-96e2-5e63c33b07d0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:48:17.433046+00
d5b0924f-9338-409c-a3b0-d2212f39ff76	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:49:00.593909+00
560c3c9b-8738-4e58-a176-5ab6ea1a6ada	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:49:45.373475+00
68c10fff-574d-4ce2-b0f8-042fd02628e1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:50:16.285513+00
ae7c4d40-57ec-4826-8e64-7914edff6d17	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:50:57.983694+00
51a1b2bc-751c-495a-99de-5423d2591f65	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:51:30.614326+00
62be8125-a957-45e4-a92c-319cfd640913	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:52:14.714576+00
9af4f368-95ea-465c-aee0-9e73616c87ea	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:52:43.264707+00
56115d56-3aeb-4553-8ae8-db57e74a913b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:53:23.806247+00
9990ceb2-9a12-4662-892b-fc471502e217	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:53:58.771668+00
6adad7ba-a4be-499c-8df2-a0c57ce43615	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:54:30.060475+00
19d684a3-c765-4008-901b-a1ee0291f84a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:54:57.907284+00
2a58b234-2537-4708-b3c9-b348848ab020	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:55:30.323873+00
31957a13-cff2-49e1-856b-cd1629dd03bf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:55:59.731792+00
72c90e6f-afdb-4549-aae4-7ff719121e30	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:56:30.319403+00
4ac565aa-a1c6-406e-9859-baf16af46136	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:56:58.093698+00
f8e6b93e-b076-40ee-a902-6f28e4e5ac2e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:57:30.874064+00
513a329f-0ee7-49e9-9df7-3b68a9dceceb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:58:14.828705+00
3ccd31cd-eef8-4faf-94de-ed311c84e1f0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:58:53.386368+00
0b4225a0-6981-483d-a56a-b80d653aafbf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 13:59:31.459436+00
c3e486dd-967a-4fce-9824-39492ad164f2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:00:27.192823+00
3ff6591f-e59a-45e0-8d55-a0b9f713d5b6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:00:59.072896+00
04361b43-cadd-47b2-a2eb-0fe0b5917901	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:01:40.501879+00
aa62dbf0-a37d-4aad-9b4d-408a7fd30fd9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:02:25.918109+00
ee9e8c60-7a2c-4f7c-a967-a8e61fc0bbf7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:02:57.290951+00
70503bca-6358-4bf3-b0ee-867fc72bc4bd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:03:38.595797+00
ca9e62e7-691d-428d-a328-58e0e7d2165a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:04:17.285634+00
e538c172-df85-4f93-8e6c-1c73251f0880	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:04:59.523031+00
afecec67-eb0e-4019-b481-36fb7e423794	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:05:29.36784+00
f3f63f3e-d3eb-49d3-9869-92081bbc0eb9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:05:57.631734+00
20547a78-94f5-414a-86de-42d0d4fca49e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:06:29.354193+00
57d70b9c-c72d-43bd-be4f-363221d6a427	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:06:58.159938+00
3cddde55-d39b-4080-8eb7-a92bc0a33cdb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:07:29.211861+00
aae35d35-6c47-42b9-9e99-a5f1f1dc806e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:07:57.216156+00
024425ad-65de-41a0-a793-3c71ad65bd1c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:08:39.191821+00
af4ec332-1463-4be3-ad87-87658c82523c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:09:16.456897+00
7d84c4e5-ec25-41da-8302-0f44e104bed0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:09:59.582395+00
f2bbac40-cbcf-44e0-aced-5cb3863e8bf9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:10:31.31865+00
5c8bd703-5b0e-49d2-a60f-76cb15e67fb5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:11:16.911115+00
abb3e6e1-98ff-4be9-aaf5-ebcb5ca3a545	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:11:58.037777+00
3557c1e8-4b53-43d6-b75a-bca58b03fc34	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:12:29.336525+00
e049d8de-4389-44be-86a9-98f6b94004fd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:12:57.247333+00
f6da7613-456d-4d70-9af6-6fa73615a5de	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:13:29.924816+00
273e2e18-3c52-4d61-b668-12847d29251c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:14:08.898301+00
33cf5983-5815-465f-8376-1b13d017751c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:14:42.57029+00
33d8f39e-c880-407d-ab05-7839505c663d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:15:14.395966+00
7f216eaf-333b-4eaa-afed-8c7e2d1627cb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:15:43.486592+00
81ca54f8-5387-4e26-9eb1-26b844f163b6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:16:14.219277+00
d9e926c5-3f6b-426d-8294-c5f8816bf61d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:16:42.605362+00
58a3bee8-a1c8-42cf-b7c9-0787a1da3de4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:17:14.825196+00
c0231691-1d91-488e-b7e3-c2a91c28d558	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:17:42.648798+00
0f76f6f7-bd3e-45cb-aaf2-62e83bc048d3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:18:14.239013+00
e6a3bed1-5ef7-44be-bd38-1fada8191dd5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:18:43.531336+00
c03456ce-9e7c-4c9d-b119-14e6363f0d46	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:19:23.695038+00
c5a3216d-5cfa-436c-89b4-d402fc932044	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:19:57.680426+00
4c634221-1660-4ecd-a90c-7b3ece6096f4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:20:29.921054+00
5c435ef7-83c2-4b9c-95c5-315e4cae6c29	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:21:02.814418+00
8d589346-5d5e-485f-a010-00ab9bc91e30	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:21:43.240694+00
0460eb5f-fc84-4540-8ac6-883023f53942	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:22:24.162907+00
7d342351-d8a9-4c03-b924-cfc4308fdec5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:22:57.750088+00
e79cbdc3-0c2b-450a-b17d-ab6712543d54	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:23:29.622236+00
83e1148e-3fe0-4ab9-be9b-ba907d9f7743	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:23:58.808831+00
46953c5e-f676-456e-aae9-e32f03375c12	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:24:39.468861+00
62c5dee1-e664-49fe-bd71-b4fc8ed72d37	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:25:14.505245+00
03d39de2-3f6f-4482-b0c1-0ce9d834f929	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:25:52.18928+00
7439fae4-fa52-4da4-b3cd-e37ac3d2e6e6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:26:29.943893+00
f5638ee3-8175-4c07-a3fa-642bee7a6d37	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:26:57.758517+00
84395183-c388-4b1d-bd61-b5cd8109a4c5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:27:29.731243+00
9c441daa-bf9d-4489-862c-9bd6a555aaa2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:27:58.080618+00
97e20a4d-318e-41e9-ad6e-e729e4c38618	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:28:32.502002+00
8b20fe3b-dff5-49bf-b05b-18ab426744d3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:29:14.604069+00
19d61591-1f00-46af-b376-652732586761	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:29:42.908384+00
160a0694-c3ce-477a-8002-6a02bf270214	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:30:15.027981+00
1307f4ea-3f90-4253-9ea7-f48aa184d68f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:30:43.241493+00
d43c2f1d-a302-4a8a-9083-15d80a2c28d7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:31:19.031747+00
1b5c5722-b94d-4da2-81eb-b07028b56ca1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:31:58.454429+00
d6f24002-2849-4105-9e20-c994d22581c8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:32:30.803193+00
61cf7755-0629-41ec-b4fd-800a4ff81ec9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:33:14.72651+00
25d4a3c9-bd90-4d82-a01e-65f8e8cfa0a8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:33:43.429416+00
c7e05903-4448-44a7-830b-85ec1f8f2b80	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:34:15.128791+00
5b5bcb9a-70e2-4b63-8fe9-bc26e4093117	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:34:43.565607+00
0f8eb23a-4946-4b7c-aaea-bab9f259f1dc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:35:14.649796+00
af98face-8f61-4428-9a99-559900a679c6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:35:42.918994+00
b2ed5cb7-c5f8-4ae9-bcd0-d705c873bc62	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:36:14.660896+00
b27ab284-cfea-4fa3-ba65-d354353c54d6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:36:43.603937+00
652ee303-c0c9-45a4-bebd-f652acef9f4e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:37:24.218706+00
a569d4cf-83a6-4a8f-8be3-53e776a8c319	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:37:58.184764+00
72c9ec6c-1d03-4756-891d-0fe004a35518	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:38:30.803003+00
b6af566a-bde5-4a7e-a7fc-457b1573df2b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:39:17.211661+00
ee96be9f-4310-468c-bca5-4fb1a4736b5f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:39:58.97323+00
d6895aec-d858-4a84-bb5b-c7cb99e6b076	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:40:29.258404+00
24b369be-26b3-4e3b-9d40-cada92941b40	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:40:57.499132+00
68c8d3e1-e7fa-4579-ab1b-9b98cd2e431a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:41:31.118383+00
e2a01310-4889-413c-abba-5e0f70373280	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:42:16.441217+00
19dbbe7a-f7a3-439c-a856-2371c4d74296	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:43:08.488984+00
89b67b79-6615-4f27-a5f1-e6cce40b6caa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:43:42.959983+00
2be17704-825a-482c-9590-e47567b9c2a2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:44:23.535261+00
f32952c6-427c-4900-9eac-36b98b85e325	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:44:57.369684+00
d9007919-4b41-4b5f-867d-54ee3d8d1b23	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:45:29.396362+00
05415d74-c4f4-451a-9400-efa49f2601f5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:45:57.196455+00
6e2c52b9-256d-4e05-a6af-9d2b669d7cc0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:46:29.912239+00
7550e61e-fc70-453c-b7ba-a8ffa1d27b40	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:46:58.687172+00
759c8f45-d9c9-49b8-9b38-fecb9e08aab4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:47:29.782792+00
7a9ca939-17fb-49e0-bd64-14a8acd33bc4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:47:56.688843+00
339331b5-1c6c-4e24-8217-73654453bb00	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:48:29.378961+00
de330057-19c4-4564-89f4-d6211ea8d13b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:48:57.478466+00
520fe2cc-d481-4a98-ae12-0c5e288acf79	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:49:29.415848+00
8c328b98-e9d8-4646-882a-1f7f24d4b1dc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:49:57.554271+00
88125481-6252-4f24-9bba-b83489046744	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:50:29.746784+00
59ebe7ff-50e0-4308-afcb-584ad850d249	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:50:57.940471+00
a51d5733-14d3-41e0-9e32-3a3510934578	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:51:30.011938+00
0f1bc6be-22f4-4240-ab65-625d7e779588	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:52:02.689482+00
8095401f-b80c-4ecd-9fe9-66905e5b8dc4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:52:43.334116+00
31563bec-6dd5-4253-abbe-1c0a10b0438f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:53:22.497386+00
e3963e1c-ec58-453c-a5fe-013aa2b7760c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:54:09.772787+00
2ffb63dd-4926-4953-84ce-37b737bc0109	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:54:43.245074+00
64a0ce02-7295-408f-85fb-43dc1bb87598	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:55:14.090116+00
cbfc5c80-751c-4cf7-a85a-e50c55296143	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:55:42.766192+00
733941ff-9082-4ce8-8497-7a929041d1ac	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:56:16.641691+00
22ed8490-166f-4818-9882-03683f330071	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:57:09.293977+00
27e1ef4c-9ec1-48af-b7d4-e0af220997cf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:57:43.601852+00
936fe606-d84a-4f8d-af22-5620cc67517f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:58:15.706924+00
96311d95-bf8f-4dda-b54d-c6b635c44ae3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:58:57.880447+00
e35e7026-bf45-4b96-869b-9323f816aa06	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:59:30.260227+00
a3d8b03a-62df-4d68-9110-a973311e0728	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 14:59:57.602367+00
8707d55e-78ed-4e66-8c43-72d71ac9389b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:00:40.078079+00
5bad1e82-b53d-4fe3-a3cb-44a95237528f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:01:15.126936+00
bea0038f-543e-4e14-873a-46f966f3f746	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:01:43.50276+00
ee8adcd1-2464-49cc-9c52-1c86c7137b09	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:02:16.811209+00
0b802fe6-a7ad-45b2-8164-536b3dcf292e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:02:58.552404+00
82092e2f-eb58-4752-911b-9f32b8e710bd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:03:29.912255+00
fcf1fd8d-f326-4bf8-9414-352282390067	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:03:57.95873+00
fe51d7bb-20fb-4852-8efa-1e0b3e851fc8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:04:30.663263+00
7ee6a1fa-6179-4455-a983-d77a7a9b1af9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:05:15.122048+00
6f3e5a53-a52f-481c-90b9-d0ebd0c780e2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:05:42.522221+00
dfad0b59-999b-4b6c-9c0f-0fc426b2dba4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:06:14.758306+00
e0e8406f-43ff-4514-909b-aa8786a4060f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:06:42.93365+00
cd5e6cd7-15d9-4b56-9ece-d2c023d2fb8c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:07:14.824156+00
455b6bc0-f681-4123-a79e-afacf17f35fd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:07:43.645088+00
128c8afd-1aa5-4ded-a249-5ef8ea1de259	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:08:14.576236+00
b47cc770-010f-4406-9af2-1244d2395268	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:08:43.135738+00
8e0c1f7d-b075-4030-a90c-983c62869c2a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:09:14.672852+00
bd42432a-82c8-43a1-9367-7e756cbccc6e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:09:43.398443+00
5f68a86e-0660-4dcb-9f3d-281957078971	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-29 15:11:20.129718+00
3c68bf69-7498-49df-82ae-07fc40b6c361	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:13:32.467928+00
0b9cb490-4596-4c29-8923-0251ec2447bf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 8m	2026-07-29 15:20:02.550779+00
9555fe99-2eb7-4311-87c3-beeda93b7339	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:20:33.749777+00
40e8224e-181d-49cc-8cea-40c0762b433a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:21:25.158098+00
512605ac-7800-4909-ba7c-39f333d63cbd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:21:57.990792+00
5e20f959-ccd4-483f-b98f-35387674d6dd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:22:29.464202+00
46437496-48b8-404b-8fd5-75b1fb7ee0c1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:22:57.570398+00
88e3315f-65fa-4360-bfc5-9ba14694cdc4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:23:29.504857+00
6e324a90-369b-41d1-bf48-9fbd3c0c7d4f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:23:58.60517+00
b824076a-7494-47e8-b8fd-138d1f5933f2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:24:29.531417+00
e565d502-265d-4169-bd13-204103c461f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:24:57.603007+00
bf1a729f-0ee7-4efb-9b0c-9bd86ae0c434	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:25:30.048214+00
503b61b2-4839-41d7-bfc3-81a71855a6dc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:25:57.503185+00
4c937c8f-a0eb-4f19-9d64-f7541131fc52	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:26:30.11495+00
8b6788e5-9db6-41c3-85a6-ea98731f7b8b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:26:58.117741+00
ace8a668-085f-4467-8f23-3116a26a67c5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:27:29.611984+00
10d7ae79-6d4b-4919-8fd2-d2b520d47d7b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:27:57.549109+00
2336fae4-ab67-41fd-8428-20abcc783a11	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:28:30.680721+00
59f8e736-1f99-4fcc-a411-15bc8bbe8256	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:29:17.110171+00
a44a35c0-c852-4b62-9857-919f8c2d4804	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:29:57.804118+00
61d8dd5b-2b25-445b-8808-bad045fa73be	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:30:29.703725+00
45f9aa0f-b567-470c-a406-ef5869a4236d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:31:00.333942+00
b52f47bd-979d-4750-b0c2-126222d6859f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:31:31.244496+00
de5e9eda-8eb6-4074-8789-eaa1a0350712	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:32:17.178475+00
4b6b2384-f6a8-4ce6-bd50-7926c5ab52a9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:32:57.891092+00
081ff06f-b042-4158-af77-41a4c632f65b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:33:39.109678+00
702c0764-54cd-4c9a-b448-04f42f896247	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:34:16.980254+00
eaba9fa2-cdf4-4119-b7b1-be42c7bf3fa3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:34:58.090099+00
f9eb5348-6eac-42ec-ac46-5357844fecf0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:35:30.495262+00
5d2087e1-6342-463f-9f57-fce0198ca4bc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:35:58.320066+00
e1adfed5-def8-4a0b-b0b5-6db2964a90b1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:36:29.820701+00
f0e65506-8989-4ca8-b2ed-90a0ff3c611b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:37:09.269552+00
f31b53ec-8e83-43af-9f47-d800f0cc0706	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:37:43.099028+00
541bf7bf-7970-4a33-acd9-bb3da57fca32	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:38:17.341776+00
ecd156ed-c011-4473-abe2-88ea20e7ea1e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:38:58.959783+00
ea482039-1389-454e-9594-deacf86a8a2d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:39:29.789577+00
0e68f31f-e787-48df-a95a-5efa8d8c81b2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:39:57.81357+00
0c800533-91f6-4731-b8f2-9c1de0d60e7e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:40:29.680595+00
29727c34-3641-4b5d-93f6-d9e85154d86f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:40:57.767092+00
8e1b799e-333d-41a7-9cad-ac2a5c88e6df	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:41:31.961602+00
27bb7f91-f19b-41ad-b12e-ef8999746f6f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:42:26.270101+00
315cac92-9bee-4adb-bf5a-fbb6a75cf46a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:42:58.085971+00
24a885d7-1f95-46c1-a8dd-73b94c990cfc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:43:30.547753+00
0f8dddf9-3bbd-416a-a2a7-657b0cd4aa31	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:43:58.448776+00
21f19d91-d4d7-4dbc-a793-c210f7d5ce2e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:44:29.970506+00
01f3dc34-c3b8-4f47-a807-c32c15a3dbcf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:45:09.681338+00
0dddc12b-3a5a-40ee-a109-8a28372325aa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:45:43.144667+00
68565663-5959-4418-a451-064bbec39ccc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:46:14.790899+00
3901f8cb-7963-4954-b209-1f9331f91a1e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:46:43.729215+00
ea488437-0c41-49e1-916b-410f57b3562e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:47:17.45731+00
402828ac-482e-4a10-9ddc-0969eee95b9f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:47:58.172546+00
f32a204e-483c-420a-bb07-11caae887619	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:48:30.059439+00
c5d23127-ad1f-48e0-8669-e40c705b76c1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:48:58.138358+00
e5d267a1-a265-4306-9a1e-1717786bdee3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:49:30.132983+00
6a6154da-5347-49ff-bed1-c26a8bbd1aaa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:50:09.101438+00
85bdcb77-62d0-42a1-a8d6-cc1b741b7250	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:50:42.214483+00
2da519bc-9528-4ff6-ad48-afce5ee5c78f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:51:13.923488+00
261dd2c9-1f0e-4f52-8f6f-9c98ed76fc98	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:51:44.470342+00
96e13ea4-e930-459c-ae9a-37341ad20cff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:52:16.368565+00
1b637680-23ee-47ae-89c8-680ad9697498	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:52:57.928456+00
b83494d9-746c-42df-b67c-e458d4c33d9b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:53:29.144936+00
1c498bde-995a-4fd6-b5cf-3fac7e18032c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:53:59.539915+00
1608aa2c-fb90-4fd9-bde6-616f31fa4241	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:54:29.953129+00
6be9a1f0-2c10-427e-99d9-18172019ce07	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:55:14.061311+00
c0d3f139-ca6a-4971-a3e0-66b2c00cd1d0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:55:42.310813+00
7ca6588a-e43a-4d2a-a191-cc3d2ef30b6f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:56:16.537019+00
fed104b3-6801-4070-87a7-ea8a201bbb2d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:56:58.562685+00
c406325b-4602-4b00-abd2-be3a05a42a56	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:57:30.21166+00
79d4c40e-3c15-4523-97d5-e58268382f06	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:58:14.264006+00
f5d6a298-c5f9-4954-9b1c-d321a4077df2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:58:42.375714+00
4b51bd0e-1a25-4311-ac1d-46aa5302ad6b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:59:14.078936+00
683e24b9-d59e-4999-8a6f-6d7b344915ec	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 15:59:43.087913+00
04781329-9c7b-4675-a979-40902f14f48d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:00:16.969705+00
0b657ac1-6c56-41dc-bf86-2336994cde07	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:00:57.496583+00
bacff4d2-09a2-41bb-a298-e637c3ecf2d6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:01:38.768274+00
2683b199-32e9-49d2-ab99-39f703a7cedc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:02:16.3119+00
a62398b8-4c31-4ddf-992f-d6583b481227	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:03:09.530006+00
1cb11ac1-e45a-430a-a551-71246feaf608	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:03:42.97639+00
27d6dce7-4ba2-41ba-a3ab-cf255e08e3f0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:04:14.063462+00
1ee41ad0-4189-4c99-81c8-ffe640b7bc2b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:04:51.768688+00
33b455f6-0daf-4f4f-9f59-7b9012b3e908	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:05:30.263359+00
d773324f-ebbb-4252-8806-0ae49b70c873	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:06:14.794132+00
0a7e9bea-aeb6-4ca5-8f40-8ca2664b4f9e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:06:43.37676+00
3f9b0323-557f-47d0-a632-d8d7237de072	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:07:25.146464+00
122aae41-6e22-4776-8616-19e67be8c3af	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:08:08.700173+00
a4fc1c66-4dd4-43d8-9a70-4c84d8c4c5f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:08:42.750378+00
5dc793ec-cf98-43ae-b283-7797a377f156	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:09:14.146003+00
b437801b-f65c-4f5c-8a10-d842884607a5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:09:42.904511+00
5a3100fe-abff-402e-96b3-6d2a27c1e520	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:10:14.167932+00
6df2eaba-cad5-4c03-877b-9de77a82128f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:10:42.473733+00
b3161401-03e9-4432-a991-d870b12931ec	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:11:14.208075+00
3ef40f9e-3e06-47e2-8f8c-61525e9159a1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:11:42.575796+00
c7df125b-fe77-4703-a197-90c7d43f01f2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:12:14.230074+00
56cc5198-ae61-4f78-86bd-09a35edea1e5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:12:45.580826+00
6e0e72fe-b7f6-4f9a-b2ae-fbb9e6483ce1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:13:30.302499+00
21f0a1a8-6ce7-41b1-8c09-d8920a0ccb79	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:13:58.347976+00
6186589b-96fe-40f9-be55-c765d265de7c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:14:30.463679+00
4a7d067f-6820-4306-b17a-8183583d04ad	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:15:14.536783+00
397a6dc7-39d0-4c0f-9bce-b28a9fe7a156	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:15:52.052585+00
17144042-e451-4a22-aeb6-b5c015a37e12	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:16:29.909449+00
8197f18f-8ad8-40d6-b5ee-810fbf0f482a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:16:57.683761+00
a6e43b7f-fa1d-4226-b3e5-97b1f056834a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:17:29.676589+00
bf7f67a1-e95c-4121-8166-c47c0ff8b404	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:17:58.780296+00
3faad953-0e97-4790-ab09-588b7d87667c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:18:30.827244+00
1198a1f0-0a62-4e15-8567-634f48b1abd9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:19:14.590189+00
9d38f290-ffd8-4a71-98f4-b4362ee23520	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:19:41.862373+00
40e05d4d-52fa-4e5e-a365-48e1e4be05ef	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:20:14.593187+00
28b41451-cf5f-40bf-9b55-7d4cbcbaaf3f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:20:42.953393+00
644e0b0c-1a49-428b-b5ee-b9e482a5ceb5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:21:14.438538+00
cc83c505-74e7-49f5-819d-4b2fd533917e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:21:42.937956+00
d50a068c-53de-4c15-94c4-dcf89a621677	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:22:14.447036+00
faeb6514-eaa7-4744-befc-8d70a60dfa4c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:22:43.363466+00
518a5090-47d0-48c4-9fc3-a37675bbfd73	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:23:19.273665+00
40954f83-cc94-49be-bcc3-37a0547b48c9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:23:58.917215+00
d7761706-bea2-41fe-bfc2-47831fbe3d5c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:24:30.445603+00
8bc56c10-f3f2-4412-b07d-e4348af109e6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:24:58.822648+00
a9a53f5a-d847-486a-bf21-ca3df70efc57	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:25:29.955745+00
0d411463-5796-4100-a5d8-1f8297bc67c9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:26:10.012085+00
5041559d-566d-44d6-884a-fa8dd2a0229b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:26:43.284098+00
889306f9-ab97-4205-885a-5e05ab2fff73	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:27:14.582904+00
b77e324d-8ac3-4416-988e-17a71451b1f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:27:43.565335+00
4cc8bd5e-9f6c-4996-9eea-13df3a023810	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:28:17.144749+00
55cb7a62-f6f6-44f8-a436-e0ad921bb527	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:28:58.605122+00
fd4677cc-a7e7-4948-9c3e-6f58dbd93bcd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:29:30.17447+00
2ae30b10-2e53-49a1-8f6e-658381acaf13	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:30:14.061507+00
18a7584d-e45c-4fc2-9731-4431cce7e7f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:30:51.60557+00
8d2d536a-0142-44de-ab89-5ff4ff18fc3b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:31:29.384282+00
ff02f37b-d6d3-47c7-85ed-7e819f60aaf6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:31:57.880121+00
cc47b5f5-dc7d-40d5-91d7-baef4fdd5a1c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:32:29.242463+00
5a511b83-ea82-471e-aac5-1ec2e8af290a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:32:57.076541+00
1418c114-6b79-4955-85af-26506ed5afdb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:33:31.204433+00
bbe4b644-ca9f-4811-9684-4a0dc5f53764	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:34:16.836559+00
c97b8ccb-6d03-4033-adfc-91618f536fc9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:34:57.465655+00
638efc1b-a71f-4553-84f6-3d5db1569fdf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:35:39.304493+00
de51162f-2aed-45cc-a2a9-afea98e3e3fd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:36:23.502851+00
4aa55289-9475-497f-9070-dd7271a87cfa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:36:57.463044+00
9366392e-f096-43f2-a024-d1b07773a7a9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:37:29.347289+00
66c2ff2b-4f66-4564-9edd-45222113a575	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:37:57.44475+00
628d6e04-a637-4704-aaad-995c7f8ce060	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:38:39.81006+00
b3bd84ac-528b-4d17-a548-e45d0d7c6551	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:39:17.815797+00
94a69218-29f9-41f1-8ec8-5b081c4f2475	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:39:57.636498+00
13812b2d-082b-4d82-bf5a-e1e0838e2641	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:40:38.865672+00
e745ac6b-9f9c-4142-99b1-83769acad897	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:41:23.649705+00
bfb818e5-ebf7-4243-ae41-693ebacf19e5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:41:57.606947+00
63c9147a-fbaf-43ab-aa39-cddef3c1f1d4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:42:28.985056+00
23a66c50-c761-481e-9bc2-cdd70950ba2f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:42:57.378502+00
2f6feb46-76f8-4f3c-b60a-62643bc25e08	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:43:40.855051+00
8a0137fa-0339-414b-aeef-25506700df0e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:44:16.70464+00
583ee873-62bc-4ed8-bcbd-1e053811287a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:44:58.174427+00
8ef99682-66a6-4eec-9dcb-cb427848de1f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:45:29.579608+00
5fa551cf-b265-4d32-8923-51d3a7eb03b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:45:58.458423+00
b560e459-0af0-4db8-ad5f-68e15cc8c6a8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:46:29.770091+00
6f83f8db-2c8a-44ba-bc66-66f28898d80c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:46:58.126025+00
2f7491f5-d129-473c-b090-d4280da0649a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:47:30.368076+00
80780b7c-6d0e-4e14-a8d5-48d03dbabef6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:48:23.827185+00
4608a5cc-317e-4c79-949e-7a8f1bfac79e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:48:57.786278+00
8d9fdb7d-3b2f-4eb9-934a-6c1f34513e33	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:49:30.094669+00
52c708b7-a7fe-4d67-b509-10cfe294f418	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:49:58.045355+00
e22f2de2-0e1f-4e7a-8527-ad643250adca	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:50:29.955932+00
31f8af01-0179-4ae4-8ff3-b91c3f2ce6f2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:50:57.656666+00
741af1cb-9ef0-4fd2-a925-46ab5cf25b6c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:51:30.161406+00
c2ff502f-d11a-438f-b3b7-8c3aee25ddd8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:51:57.645+00
af4cf3bb-729a-483a-b42c-16381af6d896	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:52:31.37393+00
d0c35da9-2736-4d13-b5f5-d16788d2dcba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:53:14.642344+00
a397a408-4d29-462b-8512-98daddb31be8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:53:54.595938+00
71af9466-6cf5-4994-9ce6-37bb08eb9190	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:54:31.504911+00
06985702-cb96-492c-a93b-17448177065c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:55:17.200447+00
5413b6d3-49c7-4992-9f04-f591a612ee0b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:55:58.951926+00
34f26a87-e9ed-44bc-8c5c-4e6572e8ade9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:56:30.068855+00
890ad2ca-c2db-41f3-83c6-87d9840cc9ff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:57:08.351895+00
63bd377b-ee40-4988-8580-1b7b04cfaa21	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:57:43.46577+00
7106f05f-a4c6-4290-a7da-90aabc9d52a5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:58:15.318393+00
900020c4-0852-42cd-a1f4-8ac1488d4f6d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:58:54.303762+00
1d52b40d-2b18-4223-87e4-34c56ff5119f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:59:30.12619+00
72686dbf-01d8-496b-9056-2dc1b234effa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 16:59:58.08352+00
26ba7f56-a806-44f9-8cf3-8a3a0e162d8c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:00:30.053488+00
8e0a270d-1218-4c04-8538-4306b2fb3d8e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:00:58.418252+00
5064979a-ba73-410f-b3b7-43b4fc38918b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:01:30.086433+00
2d761a4b-cb3c-4b9c-84e0-e14b32bdad30	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:02:13.980018+00
45f136fc-4bf1-49b0-acbc-703498b76450	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:02:42.187402+00
f234684f-dd52-4c36-b3c5-f3e1fba37ac1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:03:13.765817+00
d3c43507-abe2-45fb-afec-3b3163cbeff8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:03:42.321461+00
be96adca-752d-43cb-9bc9-1935f18e7e26	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:04:18.038868+00
11c1b251-1114-4c1f-a602-7bc77624bb75	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:04:57.964722+00
d533a36e-848b-4a95-97ac-746632ef99e7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:05:29.781856+00
fa5b3687-cb3a-465e-9fe9-a8f1a7d26670	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:05:57.676105+00
b886ce1f-7c0f-4731-8d89-431185b1366d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:06:39.122603+00
e5b31ba7-31a4-463f-9b99-e1b0c778ab3c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:07:16.703196+00
ab27a2a6-55ed-44e2-86b8-8ede137145f5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:07:58.021643+00
79bc70db-99e8-4c28-b390-1314f3f2aeb5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:08:39.178248+00
8667918e-8f01-4746-8a43-ed4ddbde042e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:09:14.627909+00
78cc98e1-047a-4e91-b5de-07b5b62eb3e8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:09:42.562623+00
66f13233-7d84-4197-a7ad-44dbc61ffc08	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:10:24.14459+00
a56f05e5-1fe5-4b74-8caa-2e1a154fc525	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:10:57.893103+00
305da54b-2a83-4324-be66-b907204a3dc6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:11:29.470415+00
d9257812-eeb0-4993-9b0c-0c7f7c4d229b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:11:58.068964+00
4628fdcf-3580-44b1-844d-73357c74faf4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:12:29.886543+00
599d1568-195a-4768-a98b-adac170ddc10	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:13:14.361514+00
899439c1-38b5-4e40-8353-7414e8964c07	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:13:42.369777+00
fb537ee4-e8b1-4571-88b3-3e98c9faa0ca	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:14:17.529431+00
3433d96f-4f05-456b-8de7-672635887b24	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:14:59.589989+00
983ca2b7-07a4-48ee-9c52-bce487045a10	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:15:30.717798+00
260bd700-4870-418e-b371-bb95268de6e4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:16:17.774781+00
5cd94593-2278-450b-a972-c4a4fb49fcfa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:16:57.689688+00
4d98297e-164d-417d-a32f-0f7aa8be4dd6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:17:30.522152+00
d5c56b14-f195-41f6-8541-f2b5aec36349	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:18:14.418877+00
c5fff038-a1be-42e3-8d76-f7c6684e7f86	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:18:42.722365+00
6ffda4aa-0ada-46cf-928e-32b5815dfde3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:19:26.036406+00
b35fa0fd-72b1-47d3-bab3-55d8945f5a14	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:19:57.731818+00
79e6cef7-de46-4de6-b4e9-c56d10af7a51	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:20:29.647947+00
dd81e689-f802-456e-b856-88a144bdae09	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:20:58.132297+00
b72e5f88-0a12-4d47-adf7-14bd2f917e4b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:21:30.129092+00
b65fbf06-a889-4f71-aeab-dbb395b23d26	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:21:58.315627+00
0ff76080-621e-4e4b-9bd4-d68d7c3e9344	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 17:22:29.596267+00
0314b4b5-1583-4460-b9ca-29a6f4466134	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-29 17:24:20.626071+00
be46828f-fc1a-4903-95fb-928ff79eca26	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 1h 58m	2026-07-29 19:23:07.41168+00
723d9a05-50ae-4298-80df-4f2897ad1921	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:23:12.931171+00
e6d99efc-4235-4890-871a-6b3b63010b85	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:23:34.910996+00
316fc601-0cd8-4881-83b0-2c81de3b6277	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:24:07.188021+00
770e2beb-8f57-4f48-949e-40a381075a57	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:24:35.675546+00
445e4a4e-d495-4cd7-a23d-513d16809541	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:25:07.075579+00
30bfe3ee-3f86-4e3f-adbe-b7dae4954ae1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:25:35.220566+00
a88c569a-b152-4856-bef6-06cb9ef53d7f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:26:06.835633+00
538231ce-1974-474f-8ed8-c5382bc499fa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:26:36.148563+00
b5c13a25-c269-4a68-82a2-509d0a8ea45e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:27:06.86824+00
4d220cd0-7b87-4c82-9e80-83a1cdbda12e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:27:35.38814+00
4d289853-c233-4668-81a3-81925ba759b8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:28:06.311572+00
dc29e9a4-3710-4ee1-9bdc-6ac6585d830a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:28:34.544486+00
ccacb124-9c82-4092-b3ff-b8856e1ff055	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:29:05.924646+00
c257e9c8-dc58-478f-9c6e-1c5863448800	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:29:33.32473+00
c5428dd4-b330-4700-99a0-e3b3918c0817	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:30:05.461196+00
e760c36a-d588-4d19-81c8-946c017536e6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:30:34.916195+00
1b827adf-f5d7-4efc-aaa6-4b988635598c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:31:04.184252+00
6b615aee-9e49-43b5-b602-4e89a6800d6e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:31:33.472124+00
55c4c2bb-3916-4622-b17e-d7107ee9d5b5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:32:05.913228+00
f1499264-6ba5-4af6-a371-5c9f37d39dc9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:32:33.963465+00
3735b6a3-120c-451f-b0f8-1aec40c14352	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:33:05.752605+00
ff21749e-b402-47f0-bfe4-60c8ffa28da5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:33:33.808053+00
8a3a041c-7f72-40c4-959b-59086b82cce7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:34:05.830104+00
6d8d52b2-14c3-4e8b-b2f8-983c26968afe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:34:34.35213+00
78ee527d-52c2-495b-abd9-18010b8691a0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:35:04.864749+00
94e709b4-4a46-405a-b202-f696f5a78fa8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:35:33.490105+00
69457899-b7bb-4e93-b4d4-e4f629c3d813	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:36:04.616654+00
e4ce2074-bb78-4050-b116-032c8c988643	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:36:33.48443+00
b19d4c1d-6ab5-443f-b9a1-f71f8449f96e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:37:04.549475+00
4aac65cd-e2ee-4013-ae94-62afbe239b92	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:37:32.563599+00
c1f0dc5e-8d4b-4f5c-ae6d-d304efa8b087	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:38:05.322306+00
aa486ff7-ba40-4109-bb4d-4c840c7c8625	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:38:32.629701+00
e5c7d227-6be5-4a5a-9616-9fcbe84aca62	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:39:04.99039+00
6c451735-574f-4947-baec-e019ebb04a7a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:39:32.730297+00
a796e7db-f740-4869-b3bc-a253034f36d4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:40:04.756644+00
f1783ce3-d3fd-4b15-9977-6b4423d96559	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:40:33.523717+00
4e831456-b07f-447b-8c08-898e774788b5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:41:05.467602+00
ece71cbd-c5c6-4287-a53f-ba46ff284f4b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:41:33.670573+00
1c81e793-6265-4cc8-ab99-c517bd0d5972	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:42:05.796649+00
a00f4966-562a-4060-a17c-6b8cd695fed3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:42:32.470287+00
94a34179-72dc-4db3-9554-a14812187de7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:43:05.425191+00
ae195928-7828-466b-9740-068059a6447c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:43:33.664282+00
347f065f-35cd-4049-ab93-a79d5723a02e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:44:06.153508+00
a063e7cb-d954-4c86-9fed-05a2d8959373	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:44:33.60504+00
420897cb-7f55-4013-a002-6e9060f9befa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:45:06.298742+00
0e810f10-7337-4709-86e1-867e6b002e09	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:45:33.883547+00
e02b3729-2b7c-40cd-ba3d-2741dc10cc0a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:46:06.276135+00
caccbfe1-1d7a-42ad-a219-6cb28ef1a654	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:46:34.464757+00
43f0fae7-d355-4237-9cc3-f2bf3e442ac8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:47:05.64876+00
b8283beb-d97b-47f4-8994-14ec2ad4f08c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:47:33.88656+00
3653536b-87ec-40d5-9202-181844177585	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:48:05.767557+00
04878e66-f3f0-4ef4-aecf-31eb90711d96	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:48:34.014141+00
55d1d90d-075d-417d-8f3b-0f60a84a629d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:49:05.874584+00
a4aad380-7544-4aaf-81ac-a77beeddb571	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:49:33.71007+00
13749e97-81ee-4fa5-a48f-f30769b6abce	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:50:05.974702+00
97d7b885-aba8-4ece-ac1e-cf478a1b96f0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:50:34.687521+00
75c2ab33-de28-4ca8-9ae0-59b7c1b487bf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:51:06.477677+00
454da38d-4268-464f-9b94-d4743c2f5f28	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:51:34.18458+00
f29d78a9-39a1-480f-80a1-56c16982df28	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:52:06.785628+00
d8890730-76e3-47ca-8548-83fe23a54c95	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:52:34.353767+00
88188a9d-66a1-4cdb-ba5a-d1c333395fe4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:53:06.571963+00
189b4e37-af2c-4cd3-b980-46321908389a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:53:35.344527+00
3ecc4608-756f-4bad-9648-2aa68627e579	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:54:06.644554+00
3f4aaf18-4540-42a3-a098-203a4dff7253	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:54:35.026638+00
42e5b11e-fcff-4626-a704-72820fc30f4c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:55:05.909572+00
97816173-359a-43cc-a253-d429a9df1bed	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:55:32.310523+00
3c4c4113-e5e4-40e5-844b-998d098c8350	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:56:05.304527+00
2261409b-b786-465d-b1b5-25088d8d6640	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:56:32.824644+00
f7709241-3f9b-41ef-b392-ae632bc4fd22	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:57:05.144735+00
e0cbf3ac-6982-46ba-9981-7071926cbf2f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:57:32.251713+00
767d7cee-8826-41bd-9cbd-91352590556a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:58:04.547319+00
850d5217-2096-4dc8-94ca-33987896a5b2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:58:33.192182+00
229b7e56-ffc5-4b08-8b6a-233276992e4a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:59:05.345068+00
7d77953b-eab7-43ae-85a8-e4372218e6f4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 19:59:33.304705+00
cfe71f1e-11c7-41e0-a880-24f5e5a9f74b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:00:04.784625+00
ed0de47b-0ac1-4ede-98b2-64d72a700984	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:00:32.574534+00
70e03aa2-208f-46bf-8aa8-55a847c0893e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:01:05.512571+00
f8e61fdd-1024-411f-ba01-9951c3f7e83e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:01:32.734312+00
db7b7013-907c-4eca-b9e2-f283537f9bc0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:02:04.214288+00
021371fc-7d6d-4967-820e-b9ee3c5dc8c8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:02:33.574547+00
4cc77656-425c-45c4-8b47-99b823c24a40	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:03:05.605235+00
9cfbb5d7-fd53-4bb1-befa-819da52e93e8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:03:33.454882+00
6f8f711e-e09a-43ba-9f84-42220641961e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:04:05.395796+00
611db0cc-0d6b-48da-a0d5-efd93ea680d3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:04:32.93563+00
b221ac7e-c804-40a1-ab09-8050bfd50470	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:05:04.335624+00
b920f169-4bdf-4cf5-8d91-099ee57268eb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:05:32.738191+00
b0460e15-0c86-4e28-82f0-9121e86c9dd7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:06:05.514405+00
2f149d6b-9b7e-4757-9840-680a8c3da694	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:06:33.015094+00
8a984925-1121-4a7a-9174-926b6dda6f6c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:07:03.913925+00
04e036ba-75d5-45b4-bb1f-dc7a27be84b9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:07:33.195261+00
2d390505-f053-4f82-82bb-2c741dc2a4f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:08:04.27422+00
3cf02573-46d5-4650-93f5-c852b1fa6bd7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:08:32.5372+00
732c48ae-3ccb-4fa6-8b3b-155f84ceebef	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:09:04.612849+00
0b70eb89-8773-4ac5-87ff-1bb0806c5bc8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:09:33.343114+00
16401b34-79e2-4c0c-8891-54fba2ba7d55	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:10:06.027206+00
896dd2a7-3b68-4ae2-acf0-faac576ed29c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:10:32.994576+00
2a652dae-905d-40b8-9071-ee6a6b1fb760	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:11:05.574619+00
854dc761-e36c-4784-8434-00da872c19b2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:11:34.334052+00
3bcb2e6f-da5a-4edc-b66e-c5fe98179cb6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:12:04.754664+00
0b758557-f1ed-40c2-887c-a2ab2b03b710	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:12:32.786265+00
0619c859-4b18-4909-8375-df2f8cc105fa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:13:06.096853+00
195a2cf9-65fb-46d9-8c3a-ee0e4d0ac657	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:13:33.194656+00
46d2b5ed-599f-4817-976a-befc8ab44a36	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:14:05.762144+00
d783fe47-feef-4c3e-b616-c2659fc89407	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:14:34.182352+00
2a5de468-9687-4ee4-8f0b-61669f6e6cca	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:15:04.882728+00
c1ac8995-3ce3-4c93-8d62-2ac17e3d709f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:15:34.255618+00
ccf8f290-2b57-4fbb-9361-26b630ade74c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:16:04.902068+00
625bda9b-ff65-4a03-bd03-81b9fde0a1a2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:16:34.273675+00
576969d2-b6ad-4ade-adb9-ff7a6eeb57b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:17:06.154297+00
88ca0109-415e-4a34-bc00-54e3be196801	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:17:32.827822+00
18aff14d-b394-4d68-b631-9e1ab030652b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:18:05.454213+00
a847ced1-6108-4380-b7b2-36fafb681f51	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:18:33.034836+00
ee402083-a806-4c48-b326-9f8e70c26d40	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:19:05.154698+00
3706d919-31e7-47d3-9976-a4a058dffa96	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:19:33.341754+00
d7e08979-f485-45a2-8896-5ed0f64e2bf9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:20:05.995006+00
f51d9b54-3650-4df5-9958-71c6c1c215da	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:20:33.833943+00
d6df2978-ea39-42bc-89ac-150abfc35234	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:21:05.874572+00
d2fdf34d-7587-4f70-aab5-f9e4617c801b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:21:32.867187+00
29af56ec-acc8-42d3-8e73-f5594e69adca	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:22:05.694647+00
109839a1-5541-44fc-878f-639ede4bd506	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:22:34.002957+00
2f139d8b-2560-4b04-9d11-86f78654be9e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:23:06.524041+00
7a89add6-f213-4394-b15e-c7fd3cef000f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:23:33.646535+00
cde1da59-714b-4286-8b7d-714fcaf869d1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:24:05.422489+00
561113f4-a255-4297-a650-af942864f4bf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:24:33.681713+00
50c50017-ea87-4ef2-a5be-463a18cf73fb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:25:06.016071+00
11f37f9b-e37d-452e-a989-967cef5d6e1d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:25:34.602196+00
b4585aad-a874-407b-ab90-cb01d4fd5ccf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:26:04.682312+00
4029ee59-f0f3-4e49-9ac4-c93947c737f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:26:32.435183+00
b0ba04ba-4580-419a-9ee8-c1af3ed2f905	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:27:04.873532+00
bb009152-8d12-4200-837d-86d7fd1b1f35	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:27:32.47861+00
e1f0406a-8618-4f26-8f3e-f0ed732cad28	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:28:05.394677+00
366d10c0-2c8d-4f35-874b-12772cc3110e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:28:31.967012+00
5aecd422-5970-4ac7-8fc0-5dc2b651b2dc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:29:03.97023+00
29dd4b84-e69a-4957-8393-7ea4ae51b9b6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:29:33.484213+00
56e27375-4e14-4b5f-9530-60bd4f98a3e1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:30:04.642588+00
c48ffa03-2884-47a3-8afd-1cb3642fd344	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:30:33.035726+00
a07f482b-3bd4-43d1-a85d-64d3540ca671	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:31:03.744966+00
4ae322e5-c860-45ce-8425-fdc24da637af	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:31:32.155629+00
607d8d9d-3726-4c57-825a-f981a996f2ed	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:32:03.814055+00
833f8bfc-ccf1-4f04-8a21-28bab5215c41	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:32:32.374777+00
dbed7c71-52b5-448b-a81c-3c5a3bf58d34	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:33:04.07491+00
09942be6-afd6-4994-90b2-53598e7066bd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:33:32.255576+00
a514874e-4512-493c-80d9-b4d5517218ce	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:34:04.274644+00
831b2204-d127-4c92-9877-03611df7d17f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:34:32.315884+00
5740fd99-19da-43ea-9d9d-97a30d65649a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:35:05.1142+00
e63cfb85-2212-443d-a08e-66bcd98c526b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:35:32.026823+00
a6ad0067-b5ea-4417-97e1-a1180ffed57a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:36:05.133942+00
2e4a74eb-d903-4a98-b4a1-fabd652fdd6c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:36:32.034906+00
80d03333-44b7-4347-9e76-b756df88400d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:37:03.954274+00
276b2324-1b2e-4980-b808-5f49b886d9fb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:37:32.255064+00
df9e523c-50d5-46bc-8cce-418cefa17fd8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:38:04.134207+00
9c334b2f-5f93-4ca1-9f0f-e08a79e09578	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:38:32.253933+00
54bedb93-5485-4cc9-818c-1446fa16f9ab	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:39:04.235451+00
a318f669-8229-4937-bedd-443747f8a4ff	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:39:33.133344+00
011be0e5-a314-4364-90ec-683af1f5b0f9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:40:05.154934+00
45e7bc65-df95-4aec-a407-1435b8820d60	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:40:32.473255+00
60e02ca4-d7bd-47fd-a72e-308416067ed4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:41:04.365349+00
9a6d9467-6915-448a-82a7-932a7930daf3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:41:33.234187+00
91d90f16-2258-45e1-bc27-c8b33af673fc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:42:04.40267+00
d12da0be-f794-4beb-ac7f-f4694fe6c534	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:42:32.314062+00
32e5f0d7-30bc-44e2-8f9a-4122b975b223	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:43:04.123123+00
8378dc91-f921-4995-a17f-ab1c064e65a7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:43:32.394047+00
affe25dc-891a-4243-85d6-453071cebea7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:44:04.422793+00
cf38ddb3-ba44-4ee7-b279-133cdf20e60f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:44:32.425533+00
d3699c5a-7b1e-4df5-8f15-7bf134bb3251	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:45:04.434667+00
4f5a8c85-87b5-4651-b178-f71388aec6c6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:45:33.354703+00
d1ad285d-bf56-40f0-9eb4-d5b3ffcff0c5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:46:05.513969+00
37b720b2-1ac1-4543-a8c0-70cadc76e288	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:46:32.46219+00
1e7b037c-8997-4677-afe4-04e617b939c0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:47:05.154819+00
d3921bd2-edc5-46e1-8641-0d035a60dbe7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:47:32.734822+00
123dad34-eb57-4447-9ec6-15569b5ea3c4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:48:04.496502+00
d9a163a7-64b3-4e92-bb65-b26005189d7b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:48:32.55519+00
0033d75a-5b90-4985-a232-ea60416c93b1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:49:05.481698+00
15c5f7aa-4e50-41ce-b4f5-ec42c691fe7c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:49:32.77897+00
12850157-4004-4519-a1ee-43f6c427675b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:50:04.433955+00
5a9a1c05-9400-452c-be12-2dcba8b68984	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:50:32.788391+00
89524147-e68d-41a0-ad6a-0327e23836ad	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:51:04.426243+00
d20ef3d5-9c72-4393-9652-fbc7302b04b6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:51:32.772593+00
2265ab2e-4447-4fce-acbe-a431e52ad518	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:52:04.614685+00
4bafaaec-dba1-4a9c-bd6e-b9bcae25151d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:52:32.813649+00
503e0405-b93e-4fce-9fc1-c3dfcabe8303	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:53:04.473752+00
4edd5964-12b4-40c7-9c9a-456e04bf538c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:53:46.85412+00
d26a7249-3ce1-4e49-b82d-7e1b0c166151	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:54:19.626555+00
ff2a3db2-048e-4994-bb49-45b19f36988f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:54:46.893649+00
32d5ce5c-57f4-4e89-bf40-65c37f0e5bce	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:55:18.874536+00
8a8c2953-f1bd-4c9c-964a-da71b1b07f53	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:55:47.017495+00
12a15ef1-a1bf-450b-a6e8-d096435410fa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:56:18.921962+00
db2d3b01-4e31-40b0-8d66-6c90a9981901	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:56:47.089732+00
526e06c0-363b-4753-bf5b-09190103f88a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:57:18.834635+00
553ae8a1-3005-4622-a123-223d1d091613	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:57:47.214188+00
78918ca6-8b8d-4141-a212-e19381832e1c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:58:18.982452+00
c0c59dd4-b237-4a3a-909e-11617e252336	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:58:47.315064+00
e463f5dd-cd4c-4fbc-adf7-58fb8a7d4cd7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:59:18.893511+00
e60a5673-708b-4eb6-be26-060f833471b5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 20:59:48.02104+00
8aaf4109-ba04-4741-b40e-d55d6630eb58	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:00:18.773579+00
f2e6810c-c60d-4bac-acdd-9889b9cd33d5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:00:47.153658+00
0f116129-b8b3-47da-ae32-a693d869f668	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:01:19.082508+00
7b9e59ef-ef3b-4694-bcd2-2d2512c15e18	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:01:47.313528+00
ed06b09d-01e6-445b-852a-42b861c4ec74	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:02:19.018745+00
b8af52b3-485b-45af-9611-a5a95443e4b3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:02:47.634974+00
fea80bc3-540a-4dc4-af56-86eb8ba0f051	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:03:19.012907+00
44a5d532-26f0-4bb8-8ef0-21b5f11b75cd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:03:47.254258+00
e0a96a09-fcde-456b-84b7-f3458ec47a53	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:04:20.013243+00
27599713-9888-43e3-a03e-b7f883cc4d0b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:04:47.462892+00
4ff5e5c5-8363-451b-8cd9-72b1ac654e4b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:05:32.614782+00
bb9ea776-4541-4235-ad58-8e0a4aa24742	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:06:16.812056+00
dd7d94f0-76da-491a-8308-a70a9ad9cf2d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:06:57.812786+00
2e960256-6adc-4241-a0f3-7507de6f7e05	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:07:29.757522+00
73582399-2c3f-4562-8944-a9f3e42095e3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:07:57.524065+00
6b0b7e08-ff62-4ffa-a99c-535089e24f77	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:08:30.003686+00
4916adf7-79af-4195-a66e-1cdbe90ddb6e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:08:57.933327+00
65a0d495-75dd-4740-85e9-7bcd2f01e54a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:09:30.245523+00
ac8bed61-cf57-4ac2-af1f-6f7ac3177808	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:10:16.506529+00
4f8cbb4a-034f-4966-ac3a-30a19100583c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:10:57.942589+00
7dff4188-2ba1-40d9-a10a-7a144f8aa28b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:11:29.791893+00
375698f1-61ff-407b-89b6-8351d41557b6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:11:57.781728+00
3bffbe55-f239-4e85-a5fa-929dce49cde6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:12:30.005972+00
8d9563f1-1097-4f9f-9515-cb2636dd9141	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:12:57.739713+00
9d333c1f-19aa-4f8c-8f61-c2c6fb00dc3c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:13:29.590613+00
9ad27c90-4a5a-427e-859d-baa95c57a5fd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:13:57.799614+00
6b8abeb2-4d0a-4375-8346-9d20049571fa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:14:29.913557+00
abab4f42-db71-47b5-9317-cc0b83bf5c67	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:14:57.808618+00
31f1684e-111d-46ee-bf7e-385fc50dcd73	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:15:30.048987+00
69d2ab46-f0de-4226-ab8b-91ede1c6bfc3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:15:59.742778+00
07715437-009e-4cea-bfa2-85f1be3ab6cc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:16:30.481549+00
8987a671-0040-40df-a6c5-44db34839224	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:17:16.835108+00
b3334dea-6472-4124-951b-9c440e1578ce	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:17:57.969491+00
07a0f62d-87c6-4511-8604-b4fbc43003ba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:18:29.967928+00
f88d12fe-e6eb-4f2b-97d0-89382c2a21e3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:18:58.018581+00
e313f719-ebac-4ceb-9733-ed6b5b2d5867	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:19:30.176082+00
17463955-595e-4086-82eb-16fe49abce2f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:19:59.040279+00
2bdd341a-adca-4501-a974-72b454e324f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:20:30.472769+00
572748e3-4a26-4bda-9a88-c3d624e6ae0a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:21:16.746118+00
3018dc3f-be45-439e-9aab-d7e67ca1cb5b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:21:58.292976+00
c67e201b-0779-440a-a9ff-7b7f11f5fa9f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:22:29.87302+00
be7c3d45-24c6-4751-9d31-742fc81ae1d4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:22:58.009511+00
5eacf0d3-bfa8-47c8-b7d9-5de44e1b7716	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:23:30.033656+00
95785a42-4f67-4861-8c8e-019bf9b76453	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:23:58.141627+00
e3d5e1d5-3c4f-4069-95bf-722b3bdf4405	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:24:30.058495+00
b1cfe989-3f55-4bd5-900d-64e6fe83d529	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:24:57.965189+00
cfe09c0d-621b-4bcf-a7da-b37d487cd792	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:25:30.098575+00
8d36ce69-d76a-4f93-952e-3b30455f51ab	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:25:58.008994+00
9e1b808f-425c-49bd-953d-7a9d04c75f76	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:26:32.313513+00
83f50bb1-4710-4386-b64c-1b23b25de2dd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:27:17.193633+00
77773d5c-d650-460c-ba39-aaf3088fb1b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:27:57.962584+00
57d273c5-aa7e-4e55-9087-65e902dc3f69	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:28:30.127846+00
7786c6bd-2d91-4fd5-b4bb-4b1520a8f055	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:28:58.145636+00
3e925f8e-8db6-4e67-bdcf-0ab569ae080e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:29:30.201703+00
39e82c52-4c1c-4c11-9c27-3c115f3de6f6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:29:58.045622+00
badb1a67-3525-44cb-aba4-f6dc34662386	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:30:29.889603+00
c151eed5-38a3-42d3-8021-ba0d0e47c45d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:30:58.338263+00
44cb1c2b-8d79-4f06-a1fd-2bb1bd69048c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:31:30.189487+00
9b763d11-be19-4b53-86e0-a0e638c67075	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:31:58.333296+00
631b64aa-02f2-49b9-a9f7-1ffd3a84b579	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:32:29.85369+00
53a43be3-d5ff-459a-993f-5284bee29265	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:32:58.089618+00
bd466526-3ecd-4901-bbf9-6f04774c1062	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:33:30.311105+00
71199ad9-7772-4ce8-ab39-ce469d2cf2ac	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:33:58.281515+00
8074a4ad-e672-4dd0-8a84-48ebf82af3c8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:34:30.296139+00
093cf343-ba12-42f6-b8e6-6a61661c52dc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:35:16.05115+00
1850f099-d071-46cf-a5f9-d24730ce0b09	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:35:57.37361+00
99a57b16-3231-4023-a923-496b88bb5173	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:36:29.713089+00
401ba20e-c79e-43dc-a429-65adca7b0811	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:36:59.461857+00
0924af95-31ec-4a54-a359-7458babeae22	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:37:29.987678+00
79d3a71c-745e-43ca-b09f-28833a938af6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:38:15.906039+00
f0fea591-dee1-4b10-86fb-9b2f3d97f54d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:38:57.489663+00
ee5049f5-1d3a-445e-895a-37b34340d54f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:39:29.352622+00
d0058be1-3247-4b2a-bd5e-884ad676f28c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:39:57.477124+00
93b22f26-e9ca-40a5-a190-d53346b7a9d7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:40:29.618815+00
0b82514b-e817-4e2d-a13a-eac035e2c285	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:40:57.286728+00
1da08aa3-7c48-4c1d-9bd2-8a651df7b3d8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:41:29.50312+00
228cb936-9930-4099-b7b1-16b66151d5f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:41:57.556693+00
2bb11116-67f3-41e0-a6a2-4fea038291a7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:42:29.636665+00
ae62d394-71ab-4fd1-81e8-a4dccf4fbecf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:42:57.588576+00
d6c07585-d8bc-4517-9479-4f9d5c4d0512	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:43:29.688799+00
a80137a9-d89b-4963-b1d3-30808f25653f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:43:57.404132+00
024921eb-f4cc-4e6b-bcd7-5d973faaf1e7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:44:29.592088+00
35b5673a-95e4-4acb-b620-4fc2e6a7b8f1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:44:57.555794+00
d7bd3884-6ee6-4699-9d24-e1ec08c3e6c7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:45:29.42813+00
7c08d7bf-1cbd-4a79-a46f-77569b58b9a4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:45:57.374662+00
81235263-822c-4cb4-8f31-20fc79667aa1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:46:30.269413+00
59c54499-814e-49a3-bcae-5f364495ac51	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:47:18.162546+00
c7ee29ec-82e0-4a1a-a922-b4f55030f1c3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:47:58.104557+00
3511e58a-65f4-4f85-8265-706c786b9d3a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:48:29.701567+00
83a7b1f8-31a1-406e-a7b7-86c42aaf44c8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:48:57.562691+00
3565fc0f-02fa-46e0-b007-127f43220526	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:49:29.664696+00
475c1bea-c49f-4dea-86ba-ef3696970032	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:49:58.876571+00
de49e76d-4733-4520-af31-d1dfabdbd140	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:50:29.789585+00
923c09fa-5811-439b-b0b0-cadfea213a55	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:50:58.62314+00
79c7fc24-ddf7-431c-a274-ab07a0910c58	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:51:29.869758+00
ec714bca-3928-48d5-89c0-98242d920f91	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:51:57.638645+00
0fab563e-85a0-4ad9-9e58-e5ccc96be845	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:52:29.676648+00
0da8f391-e6f5-466e-9e4a-3d85228540f2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:52:57.87564+00
645dcc4c-376e-4f75-b49b-d1cf25514712	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:53:29.571464+00
40d26234-a9ed-4139-82d1-c9f2846c084c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:53:57.691859+00
a65aab72-d24b-4a30-8bb5-4a5130523b4f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:54:29.814175+00
1581ce5e-dd45-48c7-8359-68d83a94254a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:54:57.797464+00
219784f8-595a-4ff9-aaf5-7facca916313	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:55:29.47461+00
f48370e7-569b-4681-9965-41e056cda821	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:55:57.89211+00
25a7981a-6654-4dd1-8412-38ec13b2356a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:56:29.948348+00
2e97ac39-c35c-417f-a558-352f5af82599	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:56:57.664624+00
256d6407-359e-4b57-91aa-71e92a64ca8c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:57:31.821547+00
dad0d373-ac58-4829-9997-35f101da7d3c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:58:17.960145+00
3ca9f0d6-d86c-4515-a522-c62f62e058a1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:58:57.971654+00
21e032ac-cca4-49c0-8350-84644d00fdb0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:59:30.139405+00
5e654563-f1eb-4efb-95da-d612c1c8f39f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 21:59:58.000948+00
2d9b468e-1155-4781-a47a-1f8ddcaf7fef	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:00:30.636298+00
a8fead25-944b-4a46-ae05-cfc9dba31a14	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:01:16.578295+00
950e570e-3ea3-4a7e-b1df-789d17bf5b84	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:01:58.191796+00
429e415b-45e5-4018-9461-2922c16234bc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:02:29.848894+00
741992f8-6fa8-4567-9254-9b8fde0d13f8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:02:58.04615+00
83504d57-10bb-479e-abbc-4461359e16df	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:03:30.099765+00
9f9f2327-4e98-4d6e-bb26-1a206fc3f73a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:03:58.03788+00
ea3d30b2-edc4-4af3-b583-07aaed3f5d43	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:04:29.908686+00
6a6bff7e-5d89-4f31-9967-136b11be8aa9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:04:58.09232+00
8862591c-0555-4500-97f0-b08dc8645654	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:05:30.10749+00
f7269768-7da1-4c9b-8c7b-ee07fd48037e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:05:58.049469+00
a7344102-1f5c-45f8-8dbd-b6b9cedf8710	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:06:29.932467+00
c6b09ddf-2ab0-431e-b47d-f34f605c79c7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:06:58.131908+00
22e1fe9c-c433-4841-8a82-597615b1ae19	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:07:30.059399+00
814658b4-dab5-44bd-90be-1b7c8691928b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:08:00.091499+00
667ce6be-16c5-41e5-851b-e2dd9e35f103	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:08:30.790024+00
cfafd7fd-3344-48cc-a0dc-770a47bab097	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:09:17.001391+00
27ca7488-1f77-4d54-a7ee-c0fc9505f477	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:09:58.404237+00
868543cf-2482-4a30-bfda-b491fa609f30	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:10:30.772895+00
bf1d077d-f207-45a3-ad2d-2a7af850b6d7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:11:17.046773+00
ef6be57c-f02e-4db2-8999-0bbdbedcf839	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:11:57.342536+00
d480ccad-4571-418e-8855-c8621005095e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:12:29.214709+00
95231296-91ec-4ab0-bb02-38c2c18c3977	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:12:57.369924+00
635868cf-634c-471c-8770-5d6a9239fe82	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:13:29.27375+00
3120b7d9-f6f5-4340-93d3-01789cd9c326	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:13:57.300516+00
1bb6d234-6600-4ca2-a81f-08d3a6bf1f43	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:14:29.588327+00
bab73247-a38b-4b62-81c4-12687242dfe3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:14:57.208364+00
236844b0-a516-444c-8f61-d1584aa7b3f2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:15:29.668568+00
c1031660-c7cf-4386-b93e-e4e3a3d3b651	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:15:57.353246+00
9e2055c0-cad3-4afa-9aa4-99073db5f616	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:16:29.616488+00
678f9e8e-7594-435b-a462-357e129f06e3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:16:57.66856+00
5b0c3eeb-6f42-4896-ac6d-d3c0617bdb50	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:17:29.774193+00
90d7bd69-863e-4e8e-aee3-bcdeec7a4bb0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:17:57.334129+00
9b3f8361-4a5b-42af-9520-58025ef55aad	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:18:31.543875+00
15eebc06-7acd-423b-8598-953df691948b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:19:16.561974+00
8d880af5-66a9-45db-abcd-f40b841b11a0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:19:57.578024+00
33b75f65-2865-4f68-b3f1-a5e61d6dd03a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:20:29.593864+00
e499db7b-08b7-4b74-b22a-62e6352117de	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:20:57.401569+00
38c696f1-b1ed-4bf0-bd47-964d27d6e624	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:21:29.478744+00
a68eec42-bca7-44b2-bfa2-c516ac641a5c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:21:57.195844+00
f0d67c57-c2b4-4331-8997-4e5932a641f0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:22:29.814556+00
2057d12a-3b75-4cab-8381-ce7ded8a06cf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:22:57.413448+00
0d33d191-0783-4e11-b107-14e71f96993a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:23:29.500791+00
007901f8-ef3b-4d3a-b211-d8418e40a868	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:23:57.388822+00
54cea868-184a-4387-93bd-1117005cf167	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:24:29.561888+00
83a48ffb-1d8b-4845-a47e-dfe9bd4be3f4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:24:57.448845+00
868f84e9-93dd-47aa-b851-5c9abef21b6d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:25:29.514432+00
b9855a95-d45d-4878-9553-85428bd4e207	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:25:57.464857+00
393bf468-c900-4f7f-b21a-8ff693551a46	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:26:29.476516+00
a3f5640b-1ab3-43be-bc8e-d297b4328a5c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:26:57.714375+00
dfdd403b-029d-4cea-8b18-2af45ba650aa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:27:29.817558+00
1a060241-46a5-4f56-b2a6-bbc62264b80f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:27:57.740452+00
7697e74c-d6f1-47f1-9ac8-67fa5399a122	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:28:29.71379+00
df35988d-6016-4adf-b3a1-d945037a49b6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:28:59.862635+00
3e2165cf-2b1c-4c46-9de6-0e198db903c0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:29:30.52087+00
f008e587-1133-4228-97d0-735543e8792b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:30:16.525917+00
103a8f1a-3e3a-4c90-bb14-f17404a2eec3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:30:57.899508+00
1ee4e9b5-ecf2-45bd-ae88-f2e0fb7311fd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:31:29.654441+00
7b8ea992-5211-44e5-90b7-eb5979c14f70	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:31:57.962859+00
f166a0fe-6223-4778-a7a2-e24f5dc24482	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:32:29.984456+00
088655b0-8442-4a27-a4aa-c2d3371c45f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:32:57.867238+00
db151dcb-7c33-4728-b62b-cb1fd92aea8d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:33:30.000326+00
155b3d81-e100-4a8e-b84c-481adc80c6a0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:33:57.950457+00
c3f154b4-86dd-4a1f-a3a3-c03ca76efc32	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:34:29.859789+00
31244ef3-8521-462b-b2c0-f4c3fa33e982	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:34:57.917944+00
6d0eee7b-2891-4888-8b5d-8cdfc0e7a4a7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:35:29.909823+00
3cb600b2-499e-448b-a11c-4b012327f48b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:35:57.927237+00
43ff9a2a-9873-451d-a6bf-11276093cd22	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:36:29.853575+00
d8744c20-e33f-441a-a724-4611b313a3b3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:36:57.983913+00
cf2e8bf2-d0b3-4efb-916e-3996179dbbb5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:37:29.944847+00
e87094cf-6f26-48dc-9cd3-31e61e695eb0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:37:57.933475+00
90a1558a-b3ee-4e6c-a24f-84a4e4dfe04f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:38:30.108481+00
d811e7d9-1893-4e5a-bd34-6ccbb7823136	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:38:58.10807+00
7de1d929-3169-4db4-849a-21e7fb83e876	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:39:32.332582+00
dc93de58-dd2c-47a3-bb57-976c124a36e7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:40:17.142103+00
5e5bb930-1504-4d09-88b3-453e5e75db73	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:40:58.0283+00
d1e548d8-36ae-4028-8a10-3bf4a7b5b296	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:41:30.190175+00
d44a4549-6942-464b-9be4-0abd4b1e83af	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:41:58.089956+00
3d9918f1-7705-417b-8bed-7c38cb361836	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:42:30.02387+00
2f3b945c-dea2-4773-8bc9-67f6e8c993a3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:42:58.215548+00
d521af86-59e6-43bc-9e8f-41e3a727b934	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:43:30.259534+00
9dd9125f-09e1-45c5-931a-4c710e323c96	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:43:58.420141+00
a6b2d5f5-5dfe-4d7e-b1aa-dcfe7352633b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:44:29.439191+00
d7278393-b414-45d0-a5bf-bc53860eb6fc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:44:57.238068+00
4023d2d5-86df-4a14-8fca-d8c7324aaa37	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:45:29.150242+00
5fb95a0a-d850-43d3-bd7f-063d9e7f40bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:45:57.031564+00
77a84df9-51e1-40d9-8000-660aaf219f69	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:46:29.299006+00
78dcb516-eaf4-4eb9-a711-d8e8afa4e7bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:46:57.481603+00
52cde6b5-37c8-479d-b364-659d9dcee12e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:47:29.455501+00
ec9a703c-744a-46ce-86e3-fcb199e8ff83	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:47:57.4736+00
c418c112-b8c2-4ce0-b981-39a1d89d8615	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:48:29.365088+00
ed3b17e5-0003-461c-87a3-1e19ce2ebacd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:48:57.584061+00
f91f1bfc-d5ce-446c-88fd-dcee574e4613	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:49:29.366088+00
08ae0a64-803f-43fd-9265-698257581ba1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:49:59.528151+00
d0eab0a8-ef44-4f58-a85f-274586582768	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:50:30.024802+00
2d39f0e5-6475-410f-8d86-57a9d24953a4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:51:16.258354+00
1519e30b-473a-48f7-8e23-ce94543cdaf6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:51:57.633464+00
d7488854-bece-4aa0-8a60-647e91db616e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:52:29.573561+00
5a8b0a04-68e8-4d27-8da5-5bde3842c111	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:52:57.508304+00
1b4cc0bf-3964-4d27-b23c-98f447ee9b41	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:53:29.715801+00
9e941137-01ab-4826-91f5-c53c119d9e85	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:53:57.260149+00
4d7e30d6-616a-4be9-a6a7-2174b2392e98	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:54:29.763122+00
3863907b-0115-4a98-aec5-3263a527b2d3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:54:57.42006+00
b687334a-e816-4e1f-abde-01f1d94dda2b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:55:29.047928+00
2e42a191-fe54-44ef-b500-d8da1c1f29c3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:55:57.537021+00
6873d990-aecd-46e0-b947-abe6f7c882ec	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:56:29.282071+00
a5ea7fe7-0b96-4dcf-b1c8-b2839d0104b2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:56:57.330152+00
bfea3dc3-5179-409c-aeb7-222326122964	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:57:29.636618+00
36e49daa-670d-4a31-8b8e-a974d2546059	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:57:57.340608+00
6a894d22-0a7f-4815-b5d2-3f782de921a3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:58:29.751319+00
7d6e9304-78e2-49c5-aee4-30f648656db5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:58:57.424303+00
f1751e6b-d114-4976-8ee4-096e8a9623dd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:59:29.614731+00
cc580b90-f886-46f0-a40f-97a176c079c9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 22:59:57.648833+00
d3a89e6d-fe3e-4929-b8d6-cdb35dc74c72	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:00:31.770745+00
f42fe25a-6ab1-4314-bc7f-c79f283693fa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-29 23:02:19.803597+00
08ed29d1-f230-4ff5-8e8a-cbb515551f8b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:02:48.215892+00
86eba17a-aa85-4aab-a8bd-8ffe3b669058	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 0m	2026-07-29 23:03:05.129706+00
3a0f2a3a-be91-4956-ac19-ba3617b52ac2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:03:56.250805+00
c30ea6f1-68c5-4553-89af-56837ce3f581	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-29 23:06:17.751436+00
22c5aad2-565b-472d-9d22-8acfd0ead568	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:06:39.287885+00
14a527be-070c-47de-bc3b-df9c3e287ee6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 0m	2026-07-29 23:07:10.075918+00
84d8c6af-78db-4266-8cca-f3f432a49d08	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:07:58.025602+00
1405058c-f6b9-4c42-9efb-062569013f54	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 445ms, jitter 250ms, loss 0%) — failed over to backup	2026-07-29 23:08:56.934091+00
fbe95a6a-6961-4c1f-a520-c5bd539a1e01	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:10:18.860789+00
d3188d0f-2ab4-4ba2-b522-d0d8099ebbb5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:11:37.737058+00
5dc4ad71-24a3-45bc-9d79-681713edcf9d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:12:29.327439+00
002f54e6-8d02-4fcd-a98b-77d2e657c607	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:13:18.469443+00
ca8d4aab-82a5-4886-90fe-d7320de52016	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:14:06.617258+00
de3e8a9a-a4c4-4d05-9dc6-bb853df2728f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:14:58.128591+00
d39ef0c2-3446-4342-89b8-73f45a4a67be	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:15:41.127562+00
9e292b93-e0de-42fb-80c1-ed5dd3a0e16c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:16:21.876667+00
67adf349-6cac-4f44-aadc-bc161bc5358a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:17:53.760753+00
1523e766-2ff1-4c11-98f8-e2fc4f0cb446	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:19:41.724929+00
10f45884-fd1d-492b-99a0-b1e70f38076a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:20:51.439604+00
593bbabe-d652-43fa-bd81-36a23c1ec657	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:22:34.483139+00
c616d6c3-3e98-4445-8cca-61a72fd2868c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:23:19.666521+00
d6912f96-3b2d-4bbf-bef2-db78b152730f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:24:21.17437+00
b4984f32-47e1-40e7-9cbf-e02b69084121	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:25:25.428849+00
27ce381d-9a59-42de-845d-9ca23f5d1a38	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-29 23:27:18.671353+00
596f2231-c28e-4e45-86eb-620e1fe29d8e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:29:28.620782+00
0fa67298-41b4-45eb-ab91-74579b62c520	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:33:30.501392+00
e886a524-2c24-4fc2-97e3-ff525100d4c5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 6m	2026-07-29 23:34:02.5761+00
1543e21c-dc28-4006-824f-5b74e4fcf485	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 238ms, jitter 210ms, loss 0%) — failed over to backup	2026-07-29 23:34:46.41805+00
877d03f4-9838-4341-8367-57158dab94d9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-29 23:36:20.151834+00
3dd64d3a-236e-4de2-a8ec-24c82275d5a3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 0m	2026-07-29 23:37:04.083594+00
18a22a7c-b95d-4753-9481-779e1d8d2329	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:37:04.424219+00
8869c643-438f-498d-9307-e1da89b11efd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:38:17.391977+00
061315e4-6443-4d9e-b190-9e1d3a232874	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:39:48.814022+00
ad470cda-39b1-4bf3-b712-482355049865	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:41:13.410431+00
61040981-c34d-4b6a-a9bc-06fac4a9c443	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:42:07.886262+00
76be5d78-c291-4276-b134-8ee5fc83c49a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:43:39.726461+00
0cf74ba7-02e4-451b-a1cf-19196a999427	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:44:25.560214+00
3c93b85d-854e-43cd-8f44-ea12986dbd69	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:45:05.879427+00
d7718846-4a3d-4595-9f6b-b92d42ed7f39	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:45:50.782114+00
754ddb1a-e72b-4c8b-8e59-777ee924e384	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:48:01.896481+00
61751f34-9a1a-443e-a34a-f3568f9afc20	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-29 23:49:11.238679+00
16e28c19-3cc3-4426-9c76-dca8782efdbe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:50:59.488615+00
65fb2d37-b61c-48fd-8b87-39d05888165f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 1m	2026-07-29 23:51:04.525249+00
aa865cfd-1b8c-452d-9789-85b7a65c657b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-29 23:53:13.178427+00
b6c2cb64-1bbf-42aa-a1dd-85e12424be0c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:53:30.343315+00
02ad6f49-73b7-41c6-9708-c3ba43a6d037	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 0m	2026-07-29 23:54:04.025735+00
8796fb82-9dd4-4a8c-9f80-7ae28bef97f9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:54:53.005066+00
8ea93d9b-b33c-4884-93c6-508641ea6fd9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:56:18.524131+00
41aa3c11-103f-487f-8fdf-fa1478a00f00	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:57:07.633153+00
4adfe2d4-3564-4d40-9ad8-b8464b58687a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:58:36.339718+00
59f36104-5a1c-41b4-8505-d79462d73112	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-29 23:59:23.485095+00
4fc2f773-e454-478a-a09a-01343f954b71	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:00:10.39911+00
3df69d9f-93fc-4986-ad9d-73d1cfb6ae12	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:01:37.04778+00
1b763bdd-f70f-4eaa-bd6c-de57f6365b61	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:02:21.963239+00
7942104c-6760-4fa2-a49e-7978ec01d864	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:03:38.265033+00
cb85d634-58d4-40f8-89e8-fd8dfc2b1dd5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:04:23.481253+00
88431e39-042e-4f70-b302-a5dcbfee1cba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:05:06.601299+00
c3513e9b-ae25-41e8-90a9-0d4bcde5f0bc	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:05:53.516633+00
eb18aed8-3a9b-4bdd-bddd-de3b5f0fb1f5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:06:42.639315+00
e1b64c42-9058-4559-a047-0174167c21f4	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:09:03.165137+00
b99f6e14-6452-4962-8057-c380d2a5d88c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:09:46.599801+00
3bd0fdf9-2c49-40b4-937a-9ad32e7c8349	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:10:46.663875+00
bdeeea77-c9a8-4d0a-9278-0bdb8987198e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:11:48.871765+00
523e056b-103a-43ab-bab2-09d897e31988	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:12:37.292439+00
6eefe128-f3dd-4d41-860e-968ebc46e1b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 527ms, jitter 155ms, loss 10%) — failed over to backup	2026-07-30 00:13:55.774429+00
e7054f85-a711-4979-9051-0c6413cb3916	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:14:59.855869+00
884ac523-3395-4d70-b6c2-3f098e3f98d5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:16:10.581668+00
05aca83d-0826-4244-a9a1-cd4fc01ab12b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:16:59.444647+00
01964588-a308-4137-902a-46495ead467f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:17:35.301928+00
8d2454f8-caed-44e0-aca8-ca7eaf2f9d6e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:18:24.483976+00
b28f22f2-c382-492f-aab1-d2cfbfbe4a9e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:20:10.208423+00
1e685a4a-c818-4535-b0f5-875463adbbd6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:20:46.598886+00
0809d192-c20f-4142-ae89-77d668c10dd1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:21:50.294779+00
af934761-5c9f-4235-9d31-cc3620ae804c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:22:35.614721+00
f20b92e3-723e-4745-bf49-0e90d07e9b8c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:23:21.558832+00
175a9308-be63-4945-927b-227e337757cd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:24:00.636683+00
532e7305-6443-4883-b77b-5053bc9d7df7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:25:05.688788+00
daa039fc-977c-4185-8915-60d6810c201b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:26:10.686918+00
da4bea37-0eab-4e32-a717-a12b8c1d6d63	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:27:09.112036+00
40591c5a-b158-4432-90c7-9f39ca0d31b0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:27:57.248847+00
b3e343c5-397c-4c27-bf1b-b97a92bbc341	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:28:58.219376+00
5c3b0e42-e597-4a0a-b376-1e08e4887ea3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:30:18.239381+00
14e5ee67-0d5b-473a-ab8b-a0f03b6ae6f3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:31:24.193189+00
e178561a-bcac-46ec-904d-f753f186066f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:32:04.474577+00
3814e5a6-3967-4d41-8131-f77b2f503308	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:32:48.52109+00
c0e043b4-55a5-4785-b1bf-161075a44eb0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:33:33.06009+00
9f6cc50f-20ad-4d9d-b7ed-f2977f38a0c5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:34:31.819305+00
02407e29-46e6-4b61-bff9-32259d4b7636	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:35:26.257114+00
51e8483c-2ae6-48fc-8edc-1b6199bcb277	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:36:20.774314+00
05ff80f9-9915-4cc8-b96e-562148e5c212	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:37:03.882943+00
65f6a0dc-412d-43c2-bc19-85ef1932d237	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:37:48.330235+00
a14e7633-81f5-4957-b114-ede1b364f20a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:38:43.360247+00
800c0b0e-b6cc-4728-8f2a-a5c1556b8ca0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:39:22.688185+00
b96f2e73-f925-49ee-8ddc-99f9e31391bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:40:29.4202+00
9b3a452a-be56-4477-99d8-8262a2f4217b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:41:57.230723+00
0f7b1d79-9a4f-4b77-8c90-29e83a573090	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:42:34.987419+00
32eb52b3-79ab-4d50-99f5-c3feee142f46	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:43:28.598454+00
7d873b09-39d2-4486-aeb7-6a5f110968a8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:44:08.104105+00
eab3e7b0-7c79-4819-b966-31a3f4e23384	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:44:50.303117+00
ce3aeea2-8798-4632-90e9-643469f28afe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:45:35.717104+00
b6865536-d452-4a39-8958-bdf2a3b5f462	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:46:34.389303+00
4026180d-b6cd-445d-bdc6-a93e1d037fab	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:47:36.979238+00
76073d57-e0b7-4dbf-a0fe-dd622bf291ef	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:48:26.754196+00
58af4f40-4011-4242-8133-c285b66513ed	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:50:15.96325+00
6ac70021-688c-478c-b6dc-ef9c6614b7d7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:51:32.739252+00
f6b083df-7e4c-474c-ace9-ea046519bb64	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:52:18.824049+00
2245478b-cae6-4e0a-bcca-eb216ca9f041	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:53:24.799939+00
021562f5-e650-47b7-bcb0-407bab10ba71	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:54:00.707216+00
0c58592d-9bae-4465-8045-a760d4c1dc5a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:54:52.540146+00
4d1ab3f0-2832-4993-8505-6efb8e5bdbaf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:55:54.798955+00
a4deb7b7-db17-4786-9379-db4c4c010fa7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:57:18.603255+00
59ccdf14-33b9-4684-a25e-14dfbbe1446d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:58:15.7902+00
8cfe5d07-26df-4fe0-95eb-42f08bf61156	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 00:59:06.159001+00
b894e90c-5e99-4e51-a338-f0fb85bf098d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 64ms, jitter 46ms, loss 0%) — failed over to backup	2026-07-30 00:59:50.04977+00
89157165-d31c-48d9-b14f-70034fdda2d2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 245ms, jitter 185ms, loss 0%) — failed over to backup	2026-07-30 01:00:44.871872+00
d1ecae62-6b71-4d6b-832e-a03085f6afdf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:01:56.176829+00
fad3cead-65ea-4873-aabe-a922585c9bc2	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:02:57.287443+00
78262414-accf-4c93-9392-e9aa61b7f937	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:03:55.07294+00
4f15f00a-6f52-4051-a3ff-aaa18488a35a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:05:32.267445+00
726bd05b-ec55-4379-a69a-aec980ed32bf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:06:27.156769+00
abe86d4f-5d1e-43f0-be0c-2c0e4925bd98	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:07:05.096962+00
8b39b478-b7cf-4003-88ef-c6da308bf54d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:07:46.609192+00
f4d4d9a8-a31f-4ea3-8682-311328cd5cf1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:08:32.643197+00
f51c6fc6-91e4-4c05-abe0-fab2a136a034	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:09:23.646772+00
fa6420c1-9783-41e2-b427-85fcd4d9d820	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 114ms, jitter 79ms, loss 0%) — failed over to backup	2026-07-30 01:10:19.759637+00
b28d970d-ff10-41cf-bb30-d84d47229351	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 116ms, jitter 106ms, loss 0%) — failed over to backup	2026-07-30 01:11:12.941868+00
8614253b-5f53-4891-84be-b968a1b12413	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:11:48.618936+00
d88eff0e-3133-4b0d-86cb-d66e250b1607	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:12:34.943413+00
4314b7b9-e730-43da-8acd-5b652b62fe1e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:13:21.145318+00
82e7c024-7797-45ad-808f-8f1d540cfe19	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:14:05.418396+00
c007e153-5df8-49b1-bba3-94a8cb6296fa	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:15:07.830353+00
70b30456-1229-4b7d-80c2-641f8a7b9d2c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:15:46.307079+00
a343fa87-7321-461d-a7fd-b90d4f3a3973	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:16:50.469661+00
f44f0e31-d6e5-4c2b-bf5c-3f9fb856e4bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:17:32.483055+00
56fa81d1-5d51-4e8a-b4bf-faaed39fe1a5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:18:18.240718+00
53d826bb-038f-4e25-9546-eef7282c9f3f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:19:06.887147+00
1bebcbec-7748-408b-b0ac-e6cde3224bd1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:20:04.497025+00
f65c18fa-0928-48f0-80b7-e8b18b1b9ac8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:21:27.085237+00
118da704-6846-4c43-a353-0dac93b702b9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-30 01:22:20.249263+00
3af629b7-f00f-4c08-a894-34e59f3eca2c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:22:38.946862+00
f4040fcf-b24f-412f-b501-37adf894c7f5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 0m	2026-07-30 01:23:02.761738+00
ab34ee89-e91e-4ec2-bfcb-5ad1becf3ef8	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:23:20.763051+00
b1ba0c25-656b-4c73-9397-cdc9f061fffe	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:24:07.499215+00
1ec91c56-0f58-435d-87f1-4f80bc7087a1	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:24:50.038527+00
c75d098f-91d7-4c1a-bc1d-4a4b31654f21	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:25:50.81928+00
be947664-dcd8-4095-998f-f69598729ef5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:26:47.724261+00
bfe6f09b-e322-405c-bf56-db8eb30bd3d7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:27:33.338218+00
fec633fd-3577-4f6e-a16a-aaf9b42d6c3d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:28:20.954876+00
01070fe9-988f-4f99-8c79-0dde30e08f44	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:29:03.472344+00
1e19f4c5-614c-4146-8fed-c32fd67a9187	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:30:31.4146+00
7ed49551-4f36-4d98-bd7c-152d7ce32f09	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:32:19.492204+00
478209a2-c4a5-4c54-a395-41ad3ed0631b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:33:19.3265+00
1f786e2d-67c2-4383-b6db-fe583a21fdb7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:34:22.1552+00
9bd40e38-3519-4cb3-916e-3fa1935b9600	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:35:13.89693+00
2ddcb552-c837-4012-a796-10a3c202b73c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:35:49.097752+00
60cd82c4-8c40-43fb-821e-1b5c49984bad	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:37:23.860352+00
1cb33d18-564b-4f99-a6ea-3faeeb3b7e7e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:38:50.284949+00
e87d67df-5984-435e-8113-962450a75047	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:39:38.619973+00
adf6ea5a-5b86-4345-96ea-48a14de1b415	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:40:25.753954+00
411a895c-b571-4540-abeb-239e16bb8e1f	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:41:07.994799+00
5d1068a8-9754-4098-a585-50987ae33e09	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:42:15.26136+00
2f73febe-ebaa-4097-b618-810537cc5be3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:42:50.0588+00
0b825733-55e8-4fb1-9fcf-5f382ad42bc9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:43:38.230744+00
8674f4af-0c72-4277-8905-3cc25f79a411	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:44:25.664826+00
82a83fda-3229-43f0-bc86-c79e124548ea	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:45:12.49186+00
905d35cf-3d9e-4d73-9ec5-fb51cfa17e1e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:45:46.572855+00
24e3504f-fb45-43c8-8c82-059a7e380e41	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:46:41.647887+00
931ef185-b920-49ae-88d8-6e9ca4bd86dd	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:47:18.214901+00
4624dd28-2eca-4376-a266-e4c64a345915	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-30 01:49:20.923557+00
864cfd08-59d5-4280-893d-88e87f7ca5b7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:52:17.072476+00
ea2c7e8c-69f9-45ea-9d58-ddc7715cb99d	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 99ms, jitter 48ms, loss 0%) — failed over to backup	2026-07-30 01:53:43.279865+00
aacea2cf-265f-4593-b3df-ca529cdf03b3	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 4m	2026-07-30 01:54:03.703755+00
d5cd8ab6-e5e4-4509-970e-ce6527eca95c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:54:19.029942+00
f25b3565-d375-4a1c-92bd-a1fa46030be9	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-30 01:56:20.115074+00
ddb728ba-1fc0-43f0-adbe-46a8484d078e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 01:58:33.026222+00
8db6f291-66cd-44f5-af8d-3bf600a9af63	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:00:38.970576+00
6c0388d3-b3a5-429b-adc9-6884b1bad610	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 4m	2026-07-30 02:01:09.146811+00
60a31368-2315-4a96-8fba-5aa2abb410f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:01:26.855673+00
82c48dc9-57ad-49eb-86bd-be3c8c5c5279	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:01:57.004669+00
6e9da62d-a349-423a-8806-955edb263e11	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:02:29.871356+00
38980aca-50e6-4300-82d6-d57207022e91	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:02:58.507859+00
4d9b74d6-7516-4b86-b56b-148e748696f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 49ms, jitter 22ms, loss 0%) — failed over to backup	2026-07-30 02:03:30.328541+00
4f6ebd3b-6a0f-433a-94ff-ae61d8b7e4c5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 51ms, jitter 21ms, loss 0%) — failed over to backup	2026-07-30 02:04:16.888303+00
f2ce274a-b4a7-40c5-9f21-0ece479d33bb	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 38ms, jitter 11ms, loss 0%) — failed over to backup	2026-07-30 02:04:59.196293+00
ddc45da6-fbd2-49e1-ad48-205d223da7f0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 40ms, jitter 22ms, loss 0%) — failed over to backup	2026-07-30 02:05:33.988222+00
b6ffca1b-7c4c-4582-97c7-76265a702d2e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 83ms, jitter 52ms, loss 0%) — failed over to backup	2026-07-30 02:06:37.392011+00
e82d492e-b12f-4164-b221-f16f4c07a802	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:07:19.232068+00
0fcca519-2be8-4941-aada-09bacfd47be5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:08:26.056345+00
49eeff6d-f695-4ec2-88a3-cc7a269c9b60	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_down	ISP link DOWN — pings to 8.8.8.8, 1.1.1.1 all failed (2 consecutive failures)	2026-07-30 02:10:19.040375+00
66ac566a-13e7-43c6-a114-13a0da97913a	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:10:37.597976+00
fe98ed66-eb54-42c9-9c34-756abf8e396c	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:12:46.161607+00
72157e2e-68b8-4039-b082-3be84e420e48	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	isp_link_up	ISP link RESTORED — outage lasted 2m	2026-07-30 02:13:03.823138+00
a9ff9b43-348a-4546-8449-c3f944da0b0b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_degraded	WAN1 degraded (lat 198ms, jitter 107ms, loss 10%) — failed over to backup	2026-07-30 02:14:12.541449+00
268d1dad-a4a7-43cf-b8d5-035f5603df2b	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:15:30.623193+00
ba31ec5c-b258-42ac-ab89-80eaf9c9fec5	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:16:57.208079+00
a9252313-734b-4e2e-ac55-3381fbb311f0	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:17:38.909175+00
fedcdd0d-7968-481b-8892-7a55d7c897f6	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:18:19.378906+00
7eb198f5-d0a9-4237-9586-ca3179461401	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:19:12.722277+00
e4a6fdf3-2a01-411f-abc1-0d307c26b027	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:19:49.508878+00
eb5daab3-cd1b-4879-8eb6-7e975c14627e	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:20:33.253013+00
096fc3ab-08c4-401f-8f7e-ed1568aa5d76	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:21:38.19234+00
70007f5e-2dd3-47ac-b880-6918174421ca	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:23:10.648824+00
cf4339ee-0aa5-4f96-b979-808606f4af97	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:23:46.666091+00
0561b121-9ccf-4287-9d9b-01b481bac353	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:24:34.966001+00
e5ad7cd7-2d56-48ed-8d94-d676f53126ba	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:25:28.977361+00
f0859097-2a3b-45be-89a3-c245b3cc1c40	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:26:06.183524+00
f83cd5d6-9a81-4c61-9103-2c2d2dc4db86	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:26:56.823969+00
1ed28230-0583-4305-bba4-090a41d64655	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:27:40.328024+00
dadfd883-f2c4-4989-9492-cd552aebe5ec	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:28:28.599363+00
42021ea2-ce07-4ad2-bd74-2de9c89a1bf7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	44a1539e-4978-474e-987b-e817d98769f7	wan_quality_recovered	WAN1 quality recovered — restored as primary	2026-07-30 02:29:03.986212+00
\.


--
-- Data for Name: nas_wan_links; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.nas_wan_links (id, nas_id, "position", name, interface, gateway, ping_target, role, lb_weight, enabled, current_status, created_at, resolved_ip, resolved_gateway, last_checked_at, last_rtt, is_active, internet_ok, in_load_balance, is_failover, failover_priority, last_latency_ms, last_jitter_ms, last_loss_pct, quality_state, consec_degraded, consec_good, quality_parked, probe_verdict, probe_stage, dns_ms, connect_ms, fetch_ms, throughput_kbps, last_fetch_at, consec_fetch_fail, sample_history, consec_slow, bytes_carried, bytes_since, last_tx_bytes, last_rx_bytes, bytes_month_start, in_pool, last_mbps, tp_checked_at) FROM stdin;
f7c97265-62d9-4c97-b26f-48b0bcc02ddf	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	1	Link 1	ether2	\N	8.8.8.8	failover_primary	50	t	standby	2026-07-29 06:23:57.058676+00	172.31.0.222/32	rl-wan-pppoe	2026-07-30 02:29:00.571337+00	78ms344us	f	t	f	t	1	92.185	71.3	0	degraded	16	1	t	good	complete	\N	\N	1253	\N	2026-07-30 02:28:46.552226+00	0	1101011110	0	2236820854	2026-07-29 06:23:57.058676+00	28714978	123981163	\N	t	\N	2026-07-30 02:28:25.925218+00
78fdf3a8-552d-40d6-aeb7-ce2fc75ed226	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	2	Link 2	ether1	\N	8.8.8.8	failover_backup	50	t	online	2026-07-29 06:23:57.061004+00	192.168.8.6/24	192.168.8.1	2026-07-30 02:29:00.572933+00	55ms954us	t	t	f	t	2	\N	\N	\N	good	0	0	f	good	complete	\N	\N	2418	\N	2026-07-30 02:29:00.2082+00	0		0	924512510	2026-07-29 06:23:57.061004+00	92871958	815295165	\N	t	\N	\N
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
80f82f77-47fd-4bd0-808f-639cb1e2aebc	\N	\N	info	New ISP Registered	Rumalink has registered on the platform (both plan)	f	\N	2026-07-29 06:14:51.406792+00
77d0ac8a-19f4-4ea9-bd1e-02571c2d77fc	44a1539e-4978-474e-987b-e817d98769f7	\N	success	MikroTik Connected	"DandoraP3" checked in. Run the import command to apply config.	f	/isp/dashboard.html	2026-07-29 06:21:44.654319+00
94429e81-9d4b-43be-a240-9c15e33296bd	44a1539e-4978-474e-987b-e817d98769f7	\N	success	MikroTik Configured	"DandoraP3" pulled and imported its config.	f	/isp/dashboard.html	2026-07-29 06:21:56.29263+00
f3d752ee-d97d-4d11-813f-3e6631cd36f4	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 30.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 06:30:00.582184+00
b8088590-273a-4bdf-aeb8-9245c84bb050	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES null credited to your wallet (IntaSend).	f	\N	2026-07-29 08:38:42.193379+00
5fb762ef-9b23-4bbd-928a-d3e7038cb8e6	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 08:59:00.777061+00
2ec19c22-f1dc-4dd1-bd06-9eb93c9362ad	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 30.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 09:39:00.7694+00
95682346-d205-4f5a-99a8-dd7677bbf10f	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 30.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 09:56:00.665755+00
01d5d0c0-6d97-4c17-b97a-f087e557523b	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 10:10:00.968249+00
6438913d-fd93-40b2-a641-4ac9d026c1c1	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 10:15:00.122671+00
3de5a16b-5d40-4702-8bda-e533f14e7f32	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 10:29:00.507379+00
4efe6f99-360f-4a1e-b718-5bbb8c2f5b6a	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 10:34:00.652663+00
44271a23-5859-4233-8b61-756c50000fbb	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 10:50:00.223883+00
c5696426-fe2e-4908-abd2-a83d00357457	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 13:48:00.64222+00
8c237ea1-9089-4ed8-b823-17dfe1c9b36e	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 19:30:00.419004+00
ad50def3-080b-42e7-aff9-596cedb469fa	44a1539e-4978-474e-987b-e817d98769f7	\N	success	Payment Received	KES 5.00 credited to your wallet (IntaSend).	f	\N	2026-07-29 19:31:00.439954+00
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
0cb2450e-0bee-490e-b2f4-b57175b66d87	44a1539e-4978-474e-987b-e817d98769f7	de2c501e-038d-42a0-9a73-290cfe90b958	\N	5.00	KES	mpesa	mpesa_stk	UGTC80PK44	\N	254117195942	0.00	0.0300	\N	paid	\N	PPPoE - 5Mbps	{"rl_consumed": "2026-07-29 08:38:38.454836+00"}	2026-07-29 08:38:38.451573+00	2026-07-29 08:38:10.141586+00	2026-07-29 08:38:10.141586+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
5008ec4b-4516-46b6-ba73-05d88577a3c5	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	UGT130S7OJ	\N	254740258495	0.90	0.0300	30.00	paid	\N	Hotspot - 24 Hours	{"rl_purchase_sms": "sent"}	2026-07-29 06:29:11.925954+00	2026-07-29 06:28:44.956628+00	2026-07-29 06:28:44.956628+00	t	\N	\N	\N	254740258495	30.00	\N	\N	\N	\N	\N	2026-07-29 06:30:00.558564+00
f001ebe1-dc26-47c9-8871-34054631dc66	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254796829688	0.15	0.0300	5.00	failed	Request failed with status code 400	Hotspot - 1 Hour	\N	\N	2026-07-29 07:40:55.075411+00	2026-07-29 07:40:55.075411+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
dccb5689-dd1c-484e-a329-dcbdb16301b9	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254796829688	0.15	0.0300	5.00	failed	Request failed with status code 400	Hotspot - 1 Hour	\N	\N	2026-07-29 07:40:57.883761+00	2026-07-29 07:40:57.883761+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bdf50013-47f6-4a5a-a359-81db4374cdfb	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254796829688	0.15	0.0300	5.00	failed	Request failed with status code 400	Hotspot - 1 Hour	\N	\N	2026-07-29 07:41:00.615212+00	2026-07-29 07:41:00.615212+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
011618db-ac47-462a-afad-a9049b3e3bbf	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254796829688	0.15	0.0300	5.00	failed	Request failed with status code 400	Hotspot - 1 Hour	\N	\N	2026-07-29 07:41:19.062805+00	2026-07-29 07:41:19.062805+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
da3a825e-60ce-4d64-95a8-85a1936f1e4d	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	\N	\N	254740258495	0.90	0.0300	30.00	failed	Request failed with status code 403	Hotspot - 24 Hours	\N	\N	2026-07-29 07:41:34.744237+00	2026-07-29 07:41:34.744237+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7a4c4224-0f9f-421c-be2d-aa1ef489a14c	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	\N	\N	254718275827	0.90	0.0300	30.00	failed	Request failed with status code 400	Hotspot - 24 Hours	\N	\N	2026-07-29 07:42:45.059489+00	2026-07-29 07:42:45.059489+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7776d755-31bd-43dd-922f-e9000ba98b8a	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa_stk	intasend	YVNL78R	RLIMS5TC1SBT8J8	254718275827	0.90	0.0300	29.10	failed	IntaSend: FAILED	Hotspot - 24 Hours	{"gross": 30, "intasend_fee": 0.9, "intasend_state": "PENDING", "intasend_invoice": "YVNL78R", "platform_commission": 0.9}	\N	2026-07-29 08:18:37.45138+00	2026-07-29 08:18:49.488681+00	t	\N	\N	\N	\N	\N	\N	CLEARING	\N	YVNL78R	\N	\N
8f1e10c0-a410-4b31-8910-27cf28f3027a	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	\N	\N	254718275827	0.90	0.0300	30.00	failed	Request failed with status code 400	Hotspot - 24 Hours	\N	\N	2026-07-29 08:22:23.426794+00	2026-07-29 08:22:23.426794+00	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
1c205184-c64a-4ef6-ac23-e48d3d94570f	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	\N	\N	254718275827	0.90	0.0300	30.00	failed	Bad Request - Invalid BusinessShortCode	Hotspot - 24 Hours	\N	\N	2026-07-29 08:29:49.776389+00	2026-07-29 08:29:49.776389+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
79266c31-8d02-4b49-bf8a-d967f1c32c15	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.90	0.0300	30.00	failed	Bad Request - Invalid BusinessShortCode	Hotspot - 24 Hours	\N	\N	2026-07-29 08:33:14.301134+00	2026-07-29 08:33:14.301134+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
f2695799-a60c-453f-bdc7-119388f902f9	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.90	0.0300	30.00	failed	Wrong credentials	Hotspot - 24 Hours	\N	\N	2026-07-29 08:34:31.043078+00	2026-07-29 08:34:31.043078+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
5f49e328-0de1-4ab4-b3e9-4285c1b5e448	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.90	0.0300	30.00	failed	Wrong credentials	Hotspot - 24 Hours	\N	\N	2026-07-29 08:34:51.402048+00	2026-07-29 08:34:51.402048+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
687d65d7-2c54-4cf4-8852-bfd9e9e6506a	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.90	0.0300	30.00	failed	Request Cancelled by user.	Hotspot - 24 Hours	\N	\N	2026-07-29 08:36:34.432804+00	2026-07-29 08:36:34.432804+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
67f61612-5454-4cf6-a4cc-5a8fa078ce3f	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	UGTC80PQPY	\N	254117195942	0.90	0.0300	30.00	paid	\N	Hotspot - 24 Hours	{"rl_healed": "R3", "rl_purchase_sms": "sent"}	2026-07-29 09:54:22.545938+00	2026-07-29 09:54:03.262854+00	2026-07-29 09:54:03.262854+00	f	\N	\N	\N	254117195942	30.00	\N	\N	\N	\N	\N	2026-07-29 09:56:00.646203+00
7e193459-dd41-4d3b-bab5-2d98d57f46bb	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGTJK0Q3I6	\N	254796829688	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_purchase_sms": "sent"}	2026-07-29 08:58:34.916879+00	2026-07-29 08:58:14.596927+00	2026-07-29 08:58:14.596927+00	f	\N	\N	\N	254796829688	5.00	\N	\N	\N	\N	\N	2026-07-29 08:59:00.763446+00
d06a9e3e-fde3-44a2-a944-69201cea4808	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.15	0.0300	5.00	failed	Request Cancelled by user.	Hotspot - 1 Hour	\N	\N	2026-07-29 09:10:23.542872+00	2026-07-29 09:10:23.542872+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7da5c03a-7f0a-4357-8f11-5bfbeb20c182	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.15	0.0300	5.00	failed	Request Cancelled by user.	Hotspot - 1 Hour	\N	\N	2026-07-29 09:32:52.100958+00	2026-07-29 09:32:52.100958+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
23c53bf2-adf0-4e5a-87ce-a416eaaad9dd	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.15	0.0300	5.00	failed	Request Cancelled by user.	Hotspot - 1 Hour	\N	\N	2026-07-29 09:33:36.690812+00	2026-07-29 09:33:36.690812+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bad374a7-f9e9-44ad-9e81-b9e1bbfc1316	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	30.00	KES	mpesa	mpesa_stk	UGTC80PNYY	\N	254117195942	0.90	0.0300	30.00	paid	\N	Hotspot - 24 Hours	{"rl_healed": "R3", "rl_purchase_sms": "sent"}	2026-07-29 09:38:32.361026+00	2026-07-29 09:38:08.934976+00	2026-07-29 09:38:08.934976+00	f	\N	\N	\N	254117195942	30.00	\N	\N	\N	\N	\N	2026-07-29 09:39:00.75589+00
9bc7ab8e-3dac-4c01-bcc5-954bd27473a6	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGTC80QKL2	\N	254117195942	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "R6", "rl_purchase_sms": "sent"}	2026-07-29 13:46:09.000867+00	2026-07-29 13:45:41.919116+00	2026-07-29 13:45:41.919116+00	f	\N	\N	\N	254117195942	5.00	\N	\N	\N	\N	\N	2026-07-29 13:48:00.613392+00
986a32ee-5bc6-4762-a251-e97506ea2f1c	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGTC80PV35	\N	254117195942	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R3", "rl_purchase_sms": "sent"}	2026-07-29 10:09:58.571843+00	2026-07-29 10:09:39.532767+00	2026-07-29 10:09:39.532767+00	f	\N	\N	\N	254117195942	5.00	\N	\N	\N	\N	\N	2026-07-29 10:10:00.938872+00
ed208752-aafe-4282-8f86-e625aee706d6	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGTC80PRDY	\N	254117195942	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R3", "rl_purchase_sms": "sent"}	2026-07-29 10:28:22.570412+00	2026-07-29 10:28:01.722066+00	2026-07-29 10:28:01.722066+00	f	\N	\N	\N	254117195942	5.00	\N	\N	\N	\N	\N	2026-07-29 10:29:00.49494+00
cfea8261-76a4-4846-b3ea-7eed2ed60d67	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGTC80PR44	\N	254117195942	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_healed": "R3", "rl_purchase_sms": "sent"}	2026-07-29 10:14:13.588196+00	2026-07-29 10:13:47.390039+00	2026-07-29 10:13:47.390039+00	f	\N	\N	\N	254117195942	5.00	\N	\N	\N	\N	\N	2026-07-29 10:15:00.095466+00
6dacdc4c-51a4-470c-a19d-769ed020283e	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.15	0.0300	5.00	failed	No response from user.	Hotspot - 1 Hour	\N	\N	2026-07-29 10:31:38.692886+00	2026-07-29 10:31:38.692886+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
d590def6-7b0c-4d9e-9385-f7508787d93e	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.15	0.0300	5.00	failed	DS timeout user cannot be reached.	Hotspot - 1 Hour	\N	\N	2026-07-29 10:32:30.315292+00	2026-07-29 10:32:30.315292+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
21d6e9a7-d565-4b1a-82ec-daed164a6d2f	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGTC80Q0R3	\N	254117195942	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"rl_purchase_sms": "sent"}	2026-07-29 10:33:27.064669+00	2026-07-29 10:33:02.776171+00	2026-07-29 10:33:02.776171+00	f	\N	\N	\N	254117195942	5.00	\N	\N	\N	\N	\N	2026-07-29 10:34:00.617538+00
e3c3e5d6-8377-4e57-a706-ff8c936755ea	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	\N	\N	254117195942	0.15	0.0300	5.00	pending	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C"}	\N	2026-07-29 10:47:39.218624+00	2026-07-29 10:47:39.218624+00	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
ab9a0b92-5348-4456-9de0-a2e0bf923311	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGTC80PVVW	\N	254117195942	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	{"is_tv": true, "tv_mac": "BC:2B:02:3A:7F:7C", "rl_healed": "R6", "rl_purchase_sms": "sent"}	2026-07-29 10:49:16.420343+00	2026-07-29 10:48:53.209051+00	2026-07-29 10:48:53.209051+00	f	\N	\N	\N	254117195942	5.00	\N	\N	\N	\N	\N	2026-07-29 10:50:00.204643+00
a39942aa-e58d-4b8d-8af1-986e4044c286	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGT391E2KW	\N	254758317799	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	\N	2026-07-29 19:29:04.738357+00	2026-07-29 19:28:46.844215+00	2026-07-29 19:28:46.844215+00	f	\N	\N	\N	254758317799	5.00	\N	\N	\N	\N	\N	2026-07-29 19:30:00.400851+00
7eeed7ef-6801-4de1-85f1-6d5aba1bb668	44a1539e-4978-474e-987b-e817d98769f7	\N	\N	5.00	KES	mpesa	mpesa_stk	UGTMT12RE6	\N	254799596989	0.15	0.0300	5.00	paid	\N	Hotspot - 1 Hour	\N	2026-07-29 19:30:55.732442+00	2026-07-29 19:30:38.022084+00	2026-07-29 19:30:38.022084+00	f	\N	\N	\N	254799596989	5.00	\N	\N	\N	\N	\N	2026-07-29 19:31:00.421402+00
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
7bbbc660-b0c4-4af1-bb88-a99f224c9ba3	44a1539e-4978-474e-987b-e817d98769f7	5Mbps	\N	5.00	monthly	5	5	\N	\N	\N	\N			t	2026-07-29 07:45:26.786363+00	2026-07-29 07:45:26.786363+00
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
de2c501e-038d-42a0-9a73-290cfe90b958	44a1539e-4978-474e-987b-e817d98769f7	7bbbc660-b0c4-4af1-bb88-a99f224c9ba3	\N	benard	$2a$10$DOWSaDsYaxId8sMsC2x.kOPrho3F8tpQ3LzpwmpXoQNX9jewn8D0e	benard	0796829688					\N	\N	\N	\N	active	0.00	2026-08-29 08:38:38.453+00	2026-07-29	\N	2026-07-29 07:46:40.292537+00	2026-07-29 08:38:38.458559+00	\N	f	f	\N
\.


--
-- Data for Name: radacct; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radacct (radacctid, acctsessionid, acctuniqueid, username, nasipaddress, nasportid, nasporttype, acctstarttime, acctstoptime, acctinterval, acctsessiontime, acctauthentic, connectinfo_start, connectinfo_stop, acctinputoctets, acctoutputoctets, calledstationid, callingstationid, acctterminatecause, servicetype, framedprotocol, framedipaddress, acctstart_delay, acctdelivery_date, realm, acctupdatetime, framedipv6address, framedipv6prefix, framedinterfaceid, delegatedipv6prefix) FROM stdin;
1	81100005	a20d7720f8a00d824a499a87cdc28f26	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-07-29 05:53:50+00	2026-07-29 06:30:15+00	\N	2185	RADIUS		\N	25701698	58478399	rumalink	50:0F:F5:36:A7:50	NAS-Reboot	Framed-User	PPP	100.64.0.254	\N	2026-07-29 06:18:51.367531+00	\N	2026-07-29 06:30:15+00	\N	\N	\N	\N
6	8100019d	d506b9d903206a6b1b62b7d621bb96e9	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-07-29 08:38:47+00	2026-07-29 12:52:07+00	300	15201	RADIUS			5106452	23771665	rumalink	50:0F:F5:36:A7:50	Lost-Carrier	Framed-User	PPP	100.64.0.254	\N	2026-07-29 08:38:47.51552+00	\N	2026-07-29 12:52:07+00	\N	\N	\N	\N
9	8000005e	2f65a8618b2271d34c63cd8cf45621d4	R3@44a1539e	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 10:28:26+00	2026-07-29 10:50:10+00	120	1304				709150	687485	rl-hotspot	BC:2B:02:3A:7F:7C	Lost-Carrier			10.100.0.151	\N	2026-07-29 10:28:26.529713+00	\N	2026-07-29 10:50:10+00	\N	\N	\N	\N
14	80100001	ee4ba1e56248ab3ce95ea40ceeadf028	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 17:05:57+00	2026-07-29 19:22:51+00	120	8214			\N	521975	1220568	rl-hotspot	66:87:6A:49:95:DA	NAS-Reboot			10.100.0.148	\N	2026-07-29 17:05:57.15364+00	\N	2026-07-29 19:22:51+00	\N	\N	\N	\N
11	80000064	eb8b117b5b2efc87016eb61f2bb4fa55	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 12:47:42+00	2026-07-29 12:54:06+00	120	383				133705	232257	rl-hotspot	66:87:6A:49:95:DA	Lost-Service			10.100.0.153	\N	2026-07-29 12:47:42.911584+00	\N	2026-07-29 12:54:06+00	\N	\N	\N	\N
10	8000005f	7e2067c5d35dc4954d24f70c700f6516	9E:A0:95:3A:BF:8D	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 11:08:12+00	2026-07-29 11:49:37+00	120	2485				132219	228166	rl-hotspot	9E:A0:95:3A:BF:8D	Session-Timeout			10.100.0.148	\N	2026-07-29 11:08:12.609393+00	\N	2026-07-29 11:49:37+00	\N	\N	\N	\N
12	80000068	53c26b788b80183934173227cd126a81	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 13:53:29+00	2026-07-29 13:55:32+00	120	123				18145	115100	rl-hotspot	66:87:6A:49:95:DA	Lost-Service			10.100.0.153	\N	2026-07-29 13:53:29.607219+00	\N	2026-07-29 13:55:32+00	\N	\N	\N	\N
8	8000005d	1acfc5346827a0b04301c6965fd4a62a	R3@44a1539e	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 10:10:00+00	2026-07-29 10:12:57+00	120	177				13307901	16852632	rl-hotspot	BC:2B:02:3A:7F:7C	Admin-Reset			10.100.0.151	\N	2026-07-29 10:10:00.725936+00	\N	2026-07-29 10:12:57+00	\N	\N	\N	\N
13	80100000	7a585fa0fb24ab8153e7071f288a61eb	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 16:50:52+00	2026-07-29 16:54:23+00	120	212				705234	2196959	rl-hotspot	66:87:6A:49:95:DA	Lost-Service			10.100.0.148	\N	2026-07-29 16:50:52.294781+00	\N	2026-07-29 16:54:23+00	\N	\N	\N	\N
4	8100019b	3c6a0770908bc7664bc0f3f136949954	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-07-29 07:47:39+00	2026-07-29 07:49:04+00	\N	85	RADIUS			636909	3431672	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-07-29 07:47:39.424777+00	\N	2026-07-29 07:49:04+00	\N	\N	\N	\N
15	80200003	28338f56ff55bb7ba4ab754e859d4ab8	R7@44a1539e	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 19:29:08+00	2026-07-29 20:29:07+00	120	3599				14473061	288617876	rl-hotspot	A6:0B:69:D9:3A:6D	Session-Timeout			10.100.0.145	\N	2026-07-29 19:29:08.694668+00	\N	2026-07-29 20:29:07+00	\N	\N	\N	\N
16	80200005	d594acff72bb1ca3b723c2452d8bc627	R8@44a1539e	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 19:30:59+00	2026-07-29 20:30:58+00	119	3599				34280396	373986072	rl-hotspot	CE:C4:E5:8C:D3:53	Session-Timeout			10.100.0.143	\N	2026-07-29 19:30:59.834677+00	\N	2026-07-29 20:30:58+00	\N	\N	\N	\N
2	8000004d	e897534394b4d3f429606cb0ce7ce670	66:87:6A:49:95:DA	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 06:30:15+00	2026-07-29 11:09:12+00	120	16737				31813310	151274672	rl-hotspot	66:87:6A:49:95:DA	Lost-Service			10.100.0.158	\N	2026-07-29 06:30:15.767084+00	\N	2026-07-29 11:09:12+00	\N	\N	\N	\N
7	80000057	28883bc969d70e489bf7477bec6c1c2d	R4@44a1539e	10.8.0.2	bridge-hotspot	Wireless-802.11	2026-07-29 08:58:38+00	2026-07-29 09:25:57+00	121	1639				10176486	223084057	rl-hotspot	3A:AD:23:80:40:76	Lost-Service			10.100.0.156	\N	2026-07-29 08:58:38.956996+00	\N	2026-07-29 09:25:57+00	\N	\N	\N	\N
5	8100019c	debe399738eb8fdf9003beebeda5cd5a	benard	10.8.0.2	bridge-hotspot	Ethernet	2026-07-29 07:49:09+00	2026-07-29 08:38:42+00	300	2972	RADIUS			1468830	170066	rumalink	50:0F:F5:36:A7:50	NAS-Request	Framed-User	PPP	100.64.0.254	\N	2026-07-29 07:49:09.570882+00	\N	2026-07-29 08:38:42+00	\N	\N	\N	\N
\.


--
-- Data for Name: radcheck; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radcheck (id, username, attribute, op, value) FROM stdin;
3	66:87:6A:49:95:DA	Cleartext-Password	:=	RLMACAUTH
5	R1@44a1539e	Cleartext-Password	:=	6c53fe
6	benard	Cleartext-Password	:=	benard2541028
7	benard	NT-Password	:=	0B340A7005F4C900BF15E1D362239383
8	R2@44a1539e	Cleartext-Password	:=	R2
31	R5@44a1539e	Cleartext-Password	:=	R5
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
1	benard		Access-Reject	2026-07-29 06:29:20.443928+00	\N
2	benard		Access-Reject	2026-07-29 06:29:26.012204+00	\N
3	benard		Access-Reject	2026-07-29 06:29:31.603916+00	\N
4	benard		Access-Reject	2026-07-29 06:29:37.063595+00	\N
5	benard		Access-Reject	2026-07-29 06:29:42.585819+00	\N
6	benard		Access-Reject	2026-07-29 06:29:48.023846+00	\N
7	benard		Access-Reject	2026-07-29 06:29:53.813886+00	\N
8	benard		Access-Reject	2026-07-29 06:29:59.130069+00	\N
9	benard		Access-Reject	2026-07-29 06:30:04.734334+00	\N
10	benard		Access-Reject	2026-07-29 06:30:11.939101+00	\N
11	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-29 06:30:15.32665+00	\N
12	benard		Access-Reject	2026-07-29 06:30:17.546391+00	\N
13	benard		Access-Reject	2026-07-29 06:30:22.769622+00	\N
14	benard		Access-Reject	2026-07-29 06:30:28.402992+00	\N
15	benard		Access-Reject	2026-07-29 06:30:34.012272+00	\N
16	benard		Access-Reject	2026-07-29 06:30:39.280563+00	\N
17	benard		Access-Reject	2026-07-29 06:30:45.011714+00	\N
18	benard		Access-Reject	2026-07-29 06:30:50.220947+00	\N
19	benard		Access-Reject	2026-07-29 06:30:55.796218+00	\N
20	benard		Access-Reject	2026-07-29 06:31:01.021345+00	\N
21	benard		Access-Reject	2026-07-29 06:31:06.70683+00	\N
22	benard		Access-Reject	2026-07-29 06:31:12.437119+00	\N
23	benard		Access-Reject	2026-07-29 06:31:17.731877+00	\N
24	benard		Access-Reject	2026-07-29 06:31:23.548367+00	\N
25	benard		Access-Reject	2026-07-29 06:31:29.091103+00	\N
26	benard		Access-Reject	2026-07-29 06:31:34.426483+00	\N
27	benard		Access-Reject	2026-07-29 06:31:39.752502+00	\N
28	benard		Access-Reject	2026-07-29 06:31:45.378212+00	\N
29	benard		Access-Reject	2026-07-29 06:31:50.594819+00	\N
30	benard		Access-Reject	2026-07-29 06:31:55.942055+00	\N
31	benard		Access-Reject	2026-07-29 06:32:01.850258+00	\N
32	benard		Access-Reject	2026-07-29 06:32:04.085225+00	\N
33	benard		Access-Reject	2026-07-29 06:32:09.478537+00	\N
34	benard		Access-Reject	2026-07-29 06:32:15.241498+00	\N
35	benard		Access-Reject	2026-07-29 06:32:21.041193+00	\N
36	benard		Access-Reject	2026-07-29 06:32:26.314026+00	\N
37	benard		Access-Reject	2026-07-29 06:32:31.96937+00	\N
38	benard		Access-Reject	2026-07-29 06:32:37.194569+00	\N
39	benard		Access-Reject	2026-07-29 06:32:42.445963+00	\N
40	benard		Access-Reject	2026-07-29 06:32:48.112905+00	\N
41	benard		Access-Reject	2026-07-29 06:32:53.344911+00	\N
42	benard		Access-Reject	2026-07-29 06:32:58.86035+00	\N
43	benard		Access-Reject	2026-07-29 06:33:04.231302+00	\N
44	benard		Access-Reject	2026-07-29 06:33:09.50549+00	\N
45	benard		Access-Reject	2026-07-29 06:33:14.815614+00	\N
46	benard		Access-Reject	2026-07-29 06:33:20.026301+00	\N
47	benard		Access-Reject	2026-07-29 06:33:25.593913+00	\N
48	benard		Access-Reject	2026-07-29 06:33:31.046579+00	\N
49	benard		Access-Reject	2026-07-29 06:33:36.602049+00	\N
50	benard		Access-Reject	2026-07-29 06:33:42.372281+00	\N
51	benard		Access-Reject	2026-07-29 06:33:47.911024+00	\N
52	benard		Access-Reject	2026-07-29 06:33:53.714065+00	\N
53	benard		Access-Reject	2026-07-29 06:33:59.038222+00	\N
54	benard		Access-Reject	2026-07-29 06:34:04.758097+00	\N
55	benard		Access-Reject	2026-07-29 06:34:09.977707+00	\N
56	benard		Access-Reject	2026-07-29 06:34:15.347743+00	\N
57	benard		Access-Reject	2026-07-29 06:34:20.838796+00	\N
58	benard		Access-Reject	2026-07-29 06:34:26.098642+00	\N
59	benard		Access-Reject	2026-07-29 06:34:31.644688+00	\N
60	benard		Access-Reject	2026-07-29 06:34:36.858561+00	\N
61	benard		Access-Reject	2026-07-29 06:34:42.258884+00	\N
62	benard		Access-Reject	2026-07-29 06:34:48.009717+00	\N
63	benard		Access-Reject	2026-07-29 06:34:53.330922+00	\N
64	benard		Access-Reject	2026-07-29 06:34:58.549472+00	\N
65	benard		Access-Reject	2026-07-29 06:35:03.779602+00	\N
66	benard		Access-Reject	2026-07-29 06:35:09.394673+00	\N
67	benard		Access-Reject	2026-07-29 06:35:14.599602+00	\N
68	benard		Access-Reject	2026-07-29 06:35:20.244798+00	\N
69	benard		Access-Reject	2026-07-29 06:35:26.031351+00	\N
70	benard		Access-Reject	2026-07-29 06:35:31.310016+00	\N
71	benard		Access-Reject	2026-07-29 06:35:37.062023+00	\N
72	benard		Access-Reject	2026-07-29 06:35:42.302586+00	\N
73	benard		Access-Reject	2026-07-29 06:35:47.995117+00	\N
74	benard		Access-Reject	2026-07-29 06:35:53.745464+00	\N
75	benard		Access-Reject	2026-07-29 06:35:59.081213+00	\N
76	benard		Access-Reject	2026-07-29 06:36:04.462601+00	\N
77	benard		Access-Reject	2026-07-29 06:36:09.771788+00	\N
78	benard		Access-Reject	2026-07-29 06:36:14.991933+00	\N
79	benard		Access-Reject	2026-07-29 06:36:20.495302+00	\N
80	benard		Access-Reject	2026-07-29 06:36:25.71191+00	\N
81	benard		Access-Reject	2026-07-29 06:36:31.052379+00	\N
82	benard		Access-Reject	2026-07-29 06:36:36.277465+00	\N
83	benard		Access-Reject	2026-07-29 06:36:41.602565+00	\N
84	benard		Access-Reject	2026-07-29 06:36:47.057411+00	\N
85	benard		Access-Reject	2026-07-29 06:36:52.272853+00	\N
86	benard		Access-Reject	2026-07-29 06:36:57.952796+00	\N
87	benard		Access-Reject	2026-07-29 06:37:03.568866+00	\N
88	benard		Access-Reject	2026-07-29 06:37:12.282043+00	\N
89	benard		Access-Reject	2026-07-29 06:37:17.809496+00	\N
90	benard		Access-Reject	2026-07-29 06:37:23.043579+00	\N
91	benard		Access-Reject	2026-07-29 06:37:28.31461+00	\N
92	benard		Access-Reject	2026-07-29 06:37:34.119288+00	\N
93	benard		Access-Reject	2026-07-29 06:37:39.45867+00	\N
94	benard		Access-Reject	2026-07-29 06:37:45.060489+00	\N
95	benard		Access-Reject	2026-07-29 06:37:50.385332+00	\N
96	benard		Access-Reject	2026-07-29 06:37:55.869474+00	\N
97	benard		Access-Reject	2026-07-29 06:38:01.38221+00	\N
98	benard		Access-Reject	2026-07-29 06:38:07.050793+00	\N
99	benard		Access-Reject	2026-07-29 06:38:12.475984+00	\N
100	benard		Access-Reject	2026-07-29 06:38:17.715673+00	\N
101	benard		Access-Reject	2026-07-29 06:38:23.282291+00	\N
102	benard		Access-Reject	2026-07-29 06:38:30.508136+00	\N
103	benard		Access-Reject	2026-07-29 06:38:35.757138+00	\N
104	benard		Access-Reject	2026-07-29 06:38:40.987378+00	\N
105	benard		Access-Reject	2026-07-29 06:38:46.338002+00	\N
106	benard		Access-Reject	2026-07-29 06:38:51.793976+00	\N
107	benard		Access-Reject	2026-07-29 06:38:57.472485+00	\N
108	benard		Access-Reject	2026-07-29 06:39:03.145702+00	\N
109	benard		Access-Reject	2026-07-29 06:39:08.387769+00	\N
110	benard		Access-Reject	2026-07-29 06:39:14.083527+00	\N
111	benard		Access-Reject	2026-07-29 06:39:19.307726+00	\N
112	benard		Access-Reject	2026-07-29 06:39:24.588671+00	\N
113	benard		Access-Reject	2026-07-29 06:39:29.911401+00	\N
114	benard		Access-Reject	2026-07-29 06:39:35.21873+00	\N
115	benard		Access-Reject	2026-07-29 06:39:40.459352+00	\N
116	benard		Access-Reject	2026-07-29 06:39:45.678852+00	\N
117	benard		Access-Reject	2026-07-29 06:39:51.453725+00	\N
118	benard		Access-Reject	2026-07-29 06:39:56.749261+00	\N
119	benard		Access-Reject	2026-07-29 06:40:02.033409+00	\N
120	benard		Access-Reject	2026-07-29 06:40:07.815042+00	\N
121	benard		Access-Reject	2026-07-29 06:40:13.335017+00	\N
122	benard		Access-Reject	2026-07-29 06:40:18.560308+00	\N
123	benard		Access-Reject	2026-07-29 06:40:23.850826+00	\N
124	benard		Access-Reject	2026-07-29 06:40:29.585094+00	\N
125	benard		Access-Reject	2026-07-29 06:40:34.980777+00	\N
126	benard		Access-Reject	2026-07-29 06:40:40.846872+00	\N
127	benard		Access-Reject	2026-07-29 06:40:46.630946+00	\N
128	benard		Access-Reject	2026-07-29 06:40:48.844754+00	\N
129	benard		Access-Reject	2026-07-29 06:40:54.495543+00	\N
130	benard		Access-Reject	2026-07-29 06:40:59.752103+00	\N
131	benard		Access-Reject	2026-07-29 06:41:05.03108+00	\N
132	benard		Access-Reject	2026-07-29 06:41:10.547101+00	\N
133	benard		Access-Reject	2026-07-29 06:41:15.791585+00	\N
134	benard		Access-Reject	2026-07-29 06:41:21.022472+00	\N
135	benard		Access-Reject	2026-07-29 06:41:26.697049+00	\N
136	benard		Access-Reject	2026-07-29 06:41:32.498244+00	\N
137	benard		Access-Reject	2026-07-29 06:41:38.266775+00	\N
138	benard		Access-Reject	2026-07-29 06:41:43.513222+00	\N
139	benard		Access-Reject	2026-07-29 06:41:48.802951+00	\N
140	benard		Access-Reject	2026-07-29 06:41:54.31744+00	\N
141	benard		Access-Reject	2026-07-29 06:42:00.033188+00	\N
142	benard		Access-Reject	2026-07-29 06:42:05.537724+00	\N
143	benard		Access-Reject	2026-07-29 06:42:10.834255+00	\N
144	benard		Access-Reject	2026-07-29 06:42:16.347689+00	\N
145	benard		Access-Reject	2026-07-29 06:42:22.078104+00	\N
146	benard		Access-Reject	2026-07-29 06:42:27.741061+00	\N
147	benard		Access-Reject	2026-07-29 06:42:33.085568+00	\N
148	benard		Access-Reject	2026-07-29 06:42:38.314451+00	\N
149	benard		Access-Reject	2026-07-29 06:42:43.890455+00	\N
150	benard		Access-Reject	2026-07-29 06:42:49.165373+00	\N
151	benard		Access-Reject	2026-07-29 06:42:54.930725+00	\N
152	benard		Access-Reject	2026-07-29 06:43:00.265656+00	\N
153	benard		Access-Reject	2026-07-29 06:43:08.902961+00	\N
154	benard		Access-Reject	2026-07-29 06:43:14.371617+00	\N
155	benard		Access-Reject	2026-07-29 06:43:19.928076+00	\N
156	benard		Access-Reject	2026-07-29 06:43:25.177065+00	\N
157	benard		Access-Reject	2026-07-29 06:43:30.516704+00	\N
158	benard		Access-Reject	2026-07-29 06:43:35.976334+00	\N
159	benard		Access-Reject	2026-07-29 06:43:41.257367+00	\N
160	benard		Access-Reject	2026-07-29 06:43:46.548489+00	\N
161	benard		Access-Reject	2026-07-29 06:43:51.777732+00	\N
162	benard		Access-Reject	2026-07-29 06:43:57.017311+00	\N
163	benard		Access-Reject	2026-07-29 06:44:02.328568+00	\N
164	benard		Access-Reject	2026-07-29 06:44:07.772824+00	\N
165	benard		Access-Reject	2026-07-29 06:44:12.99765+00	\N
166	benard		Access-Reject	2026-07-29 06:44:18.288228+00	\N
167	benard		Access-Reject	2026-07-29 06:44:23.732285+00	\N
168	benard		Access-Reject	2026-07-29 06:44:30.958345+00	\N
169	benard		Access-Reject	2026-07-29 06:44:36.220824+00	\N
170	benard		Access-Reject	2026-07-29 06:44:41.569341+00	\N
171	benard		Access-Reject	2026-07-29 06:44:47.284525+00	\N
172	benard		Access-Reject	2026-07-29 06:44:52.825201+00	\N
173	benard		Access-Reject	2026-07-29 06:44:58.435472+00	\N
174	benard		Access-Reject	2026-07-29 06:45:04.276189+00	\N
175	benard		Access-Reject	2026-07-29 06:45:09.72951+00	\N
176	benard		Access-Reject	2026-07-29 06:45:14.970385+00	\N
177	benard		Access-Reject	2026-07-29 06:45:20.300264+00	\N
178	benard		Access-Reject	2026-07-29 06:45:25.641338+00	\N
179	benard		Access-Reject	2026-07-29 06:45:31.076569+00	\N
180	benard		Access-Reject	2026-07-29 06:45:36.311017+00	\N
181	benard		Access-Reject	2026-07-29 06:45:41.642684+00	\N
182	benard		Access-Reject	2026-07-29 06:45:46.911576+00	\N
183	benard		Access-Reject	2026-07-29 06:45:52.142096+00	\N
184	benard		Access-Reject	2026-07-29 06:45:57.426097+00	\N
185	benard		Access-Reject	2026-07-29 06:46:03.088124+00	\N
186	benard		Access-Reject	2026-07-29 06:46:08.451551+00	\N
187	benard		Access-Reject	2026-07-29 06:46:14.188336+00	\N
188	benard		Access-Reject	2026-07-29 06:46:19.463635+00	\N
189	benard		Access-Reject	2026-07-29 06:46:24.722142+00	\N
190	benard		Access-Reject	2026-07-29 06:46:30.449451+00	\N
191	benard		Access-Reject	2026-07-29 06:46:35.79273+00	\N
192	benard		Access-Reject	2026-07-29 06:46:41.143993+00	\N
193	benard		Access-Reject	2026-07-29 06:46:49.363964+00	\N
194	benard		Access-Reject	2026-07-29 06:46:54.803385+00	\N
195	benard		Access-Reject	2026-07-29 06:47:00.41934+00	\N
196	benard		Access-Reject	2026-07-29 06:47:05.694003+00	\N
197	benard		Access-Reject	2026-07-29 06:47:11.359604+00	\N
198	benard		Access-Reject	2026-07-29 06:47:16.684749+00	\N
199	benard		Access-Reject	2026-07-29 06:47:22.400324+00	\N
200	benard		Access-Reject	2026-07-29 06:47:27.908756+00	\N
201	benard		Access-Reject	2026-07-29 06:47:33.15518+00	\N
202	benard		Access-Reject	2026-07-29 06:47:38.940284+00	\N
203	benard		Access-Reject	2026-07-29 06:47:44.305527+00	\N
204	benard		Access-Reject	2026-07-29 06:47:49.545469+00	\N
205	benard		Access-Reject	2026-07-29 06:47:54.825908+00	\N
206	benard		Access-Reject	2026-07-29 06:48:00.093228+00	\N
207	benard		Access-Reject	2026-07-29 06:48:05.31635+00	\N
208	benard		Access-Reject	2026-07-29 06:48:10.555537+00	\N
209	benard		Access-Reject	2026-07-29 06:48:16.34386+00	\N
210	benard		Access-Reject	2026-07-29 06:48:21.726475+00	\N
211	benard		Access-Reject	2026-07-29 06:48:26.976257+00	\N
212	benard		Access-Reject	2026-07-29 06:48:32.297001+00	\N
213	benard		Access-Reject	2026-07-29 06:48:37.536576+00	\N
214	benard		Access-Reject	2026-07-29 06:48:43.024364+00	\N
215	benard		Access-Reject	2026-07-29 06:48:48.398028+00	\N
216	benard		Access-Reject	2026-07-29 06:48:53.629467+00	\N
217	benard		Access-Reject	2026-07-29 06:48:58.857135+00	\N
218	benard		Access-Reject	2026-07-29 06:49:04.695082+00	\N
219	benard		Access-Reject	2026-07-29 06:49:10.018598+00	\N
220	benard		Access-Reject	2026-07-29 06:49:15.388383+00	\N
221	benard		Access-Reject	2026-07-29 06:49:20.697951+00	\N
222	benard		Access-Reject	2026-07-29 06:49:26.414498+00	\N
223	benard		Access-Reject	2026-07-29 06:49:32.273051+00	\N
224	benard		Access-Reject	2026-07-29 06:49:37.498792+00	\N
225	benard		Access-Reject	2026-07-29 06:49:42.720182+00	\N
226	benard		Access-Reject	2026-07-29 06:49:47.929363+00	\N
227	benard		Access-Reject	2026-07-29 06:49:53.293984+00	\N
228	benard		Access-Reject	2026-07-29 06:49:59.134869+00	\N
229	benard		Access-Reject	2026-07-29 06:50:04.955865+00	\N
230	benard		Access-Reject	2026-07-29 06:50:10.794678+00	\N
231	benard		Access-Reject	2026-07-29 06:50:16.395227+00	\N
232	benard		Access-Reject	2026-07-29 06:50:21.610278+00	\N
233	benard		Access-Reject	2026-07-29 06:50:26.830296+00	\N
234	benard		Access-Reject	2026-07-29 06:50:32.041103+00	\N
235	benard		Access-Reject	2026-07-29 06:50:37.717037+00	\N
236	benard		Access-Reject	2026-07-29 06:50:43.467198+00	\N
237	benard		Access-Reject	2026-07-29 06:50:48.766803+00	\N
238	benard		Access-Reject	2026-07-29 06:50:54.464244+00	\N
239	benard		Access-Reject	2026-07-29 06:50:59.762092+00	\N
240	benard		Access-Reject	2026-07-29 06:51:04.972583+00	\N
242	benard		Access-Reject	2026-07-29 06:51:15.555569+00	\N
244	benard		Access-Reject	2026-07-29 06:51:26.112861+00	\N
246	benard		Access-Reject	2026-07-29 06:51:37.408281+00	\N
248	benard		Access-Reject	2026-07-29 06:51:48.819422+00	\N
250	benard		Access-Reject	2026-07-29 06:51:59.423799+00	\N
252	benard		Access-Reject	2026-07-29 06:52:10.421937+00	\N
241	benard		Access-Reject	2026-07-29 06:51:10.211793+00	\N
243	benard		Access-Reject	2026-07-29 06:51:20.874318+00	\N
245	benard		Access-Reject	2026-07-29 06:51:31.878922+00	\N
247	benard		Access-Reject	2026-07-29 06:51:42.987554+00	\N
249	benard		Access-Reject	2026-07-29 06:51:54.17499+00	\N
251	benard		Access-Reject	2026-07-29 06:52:05.099156+00	\N
253	benard		Access-Reject	2026-07-29 06:52:15.727706+00	\N
255	benard		Access-Reject	2026-07-29 06:52:26.774792+00	\N
257	benard		Access-Reject	2026-07-29 06:52:37.235216+00	\N
259	benard		Access-Reject	2026-07-29 06:52:50.745855+00	\N
261	benard		Access-Reject	2026-07-29 06:53:01.195905+00	\N
254	benard		Access-Reject	2026-07-29 06:52:21.52175+00	\N
256	benard		Access-Reject	2026-07-29 06:52:31.984544+00	\N
258	benard		Access-Reject	2026-07-29 06:52:42.536218+00	\N
260	benard		Access-Reject	2026-07-29 06:52:55.996282+00	\N
262	benard		Access-Reject	2026-07-29 06:53:06.940279+00	\N
263	benard		Access-Reject	2026-07-29 06:53:12.472638+00	\N
264	benard		Access-Reject	2026-07-29 06:53:18.131311+00	\N
265	benard		Access-Reject	2026-07-29 06:53:23.456891+00	\N
266	benard		Access-Reject	2026-07-29 06:53:28.687013+00	\N
267	benard		Access-Reject	2026-07-29 06:53:33.99723+00	\N
268	benard		Access-Reject	2026-07-29 06:53:39.635248+00	\N
269	benard		Access-Reject	2026-07-29 06:53:45.111726+00	\N
270	benard		Access-Reject	2026-07-29 06:53:50.43758+00	\N
271	benard		Access-Reject	2026-07-29 06:53:56.184846+00	\N
272	benard		Access-Reject	2026-07-29 06:54:02.001872+00	\N
273	benard		Access-Reject	2026-07-29 06:54:07.732979+00	\N
274	benard		Access-Reject	2026-07-29 06:54:13.314392+00	\N
275	benard		Access-Reject	2026-07-29 06:54:18.683788+00	\N
276	benard		Access-Reject	2026-07-29 06:54:24.204468+00	\N
277	benard		Access-Reject	2026-07-29 06:54:29.438581+00	\N
278	benard		Access-Reject	2026-07-29 06:54:34.649071+00	\N
279	benard		Access-Reject	2026-07-29 06:54:39.859409+00	\N
280	benard		Access-Reject	2026-07-29 06:54:45.150307+00	\N
281	benard		Access-Reject	2026-07-29 06:54:51.004573+00	\N
282	benard		Access-Reject	2026-07-29 06:54:56.414766+00	\N
283	benard		Access-Reject	2026-07-29 06:55:01.659881+00	\N
284	benard		Access-Reject	2026-07-29 06:55:06.949986+00	\N
285	benard		Access-Reject	2026-07-29 06:55:12.516558+00	\N
286	benard		Access-Reject	2026-07-29 06:55:17.730371+00	\N
287	benard		Access-Reject	2026-07-29 06:55:23.040732+00	\N
288	benard		Access-Reject	2026-07-29 06:55:28.56086+00	\N
289	benard		Access-Reject	2026-07-29 06:55:33.851187+00	\N
290	benard		Access-Reject	2026-07-29 06:55:39.522685+00	\N
291	benard		Access-Reject	2026-07-29 06:55:44.781145+00	\N
292	benard		Access-Reject	2026-07-29 06:55:50.217496+00	\N
293	benard		Access-Reject	2026-07-29 06:55:55.481536+00	\N
294	benard		Access-Reject	2026-07-29 06:56:00.833547+00	\N
295	benard		Access-Reject	2026-07-29 06:56:06.17215+00	\N
296	benard		Access-Reject	2026-07-29 06:56:11.573259+00	\N
297	benard		Access-Reject	2026-07-29 06:56:17.156792+00	\N
298	benard		Access-Reject	2026-07-29 06:56:22.432837+00	\N
299	benard		Access-Reject	2026-07-29 06:56:27.713499+00	\N
300	benard		Access-Reject	2026-07-29 06:56:33.179883+00	\N
301	benard		Access-Reject	2026-07-29 06:56:38.413444+00	\N
302	benard		Access-Reject	2026-07-29 06:56:44.192333+00	\N
303	benard		Access-Reject	2026-07-29 06:56:49.56929+00	\N
304	benard		Access-Reject	2026-07-29 06:56:54.79399+00	\N
305	benard		Access-Reject	2026-07-29 06:57:00.350051+00	\N
306	benard		Access-Reject	2026-07-29 06:57:05.72376+00	\N
307	benard		Access-Reject	2026-07-29 06:57:10.964335+00	\N
308	benard		Access-Reject	2026-07-29 06:57:16.364527+00	\N
309	benard		Access-Reject	2026-07-29 06:57:21.724556+00	\N
310	benard		Access-Reject	2026-07-29 06:57:27.05537+00	\N
311	benard		Access-Reject	2026-07-29 06:57:32.436476+00	\N
312	benard		Access-Reject	2026-07-29 06:57:37.879595+00	\N
313	benard		Access-Reject	2026-07-29 06:57:43.085854+00	\N
314	benard		Access-Reject	2026-07-29 06:57:48.870462+00	\N
315	benard		Access-Reject	2026-07-29 06:57:54.105422+00	\N
316	benard		Access-Reject	2026-07-29 06:57:59.416391+00	\N
317	benard		Access-Reject	2026-07-29 06:58:05.18108+00	\N
318	benard		Access-Reject	2026-07-29 06:58:10.851427+00	\N
319	benard		Access-Reject	2026-07-29 06:58:16.357024+00	\N
320	benard		Access-Reject	2026-07-29 06:58:21.656551+00	\N
321	benard		Access-Reject	2026-07-29 06:58:27.026952+00	\N
322	benard		Access-Reject	2026-07-29 06:58:32.406756+00	\N
323	benard		Access-Reject	2026-07-29 06:58:37.669751+00	\N
324	benard		Access-Reject	2026-07-29 06:58:43.442968+00	\N
325	benard		Access-Reject	2026-07-29 06:58:48.902816+00	\N
326	benard		Access-Reject	2026-07-29 06:58:54.243392+00	\N
327	benard		Access-Reject	2026-07-29 06:58:59.530077+00	\N
328	benard		Access-Reject	2026-07-29 06:59:04.83857+00	\N
329	benard		Access-Reject	2026-07-29 06:59:10.23891+00	\N
330	benard		Access-Reject	2026-07-29 06:59:15.448593+00	\N
331	benard		Access-Reject	2026-07-29 06:59:20.98338+00	\N
332	benard		Access-Reject	2026-07-29 06:59:26.588758+00	\N
333	benard		Access-Reject	2026-07-29 06:59:31.909632+00	\N
334	benard		Access-Reject	2026-07-29 06:59:37.180938+00	\N
335	benard		Access-Reject	2026-07-29 06:59:42.439388+00	\N
336	benard		Access-Reject	2026-07-29 06:59:47.639837+00	\N
337	benard		Access-Reject	2026-07-29 06:59:53.3265+00	\N
338	benard		Access-Reject	2026-07-29 06:59:58.610467+00	\N
339	benard		Access-Reject	2026-07-29 07:00:04.314333+00	\N
340	benard		Access-Reject	2026-07-29 07:00:09.570156+00	\N
341	benard		Access-Reject	2026-07-29 07:00:14.991593+00	\N
342	benard		Access-Reject	2026-07-29 07:00:20.523672+00	\N
343	benard		Access-Reject	2026-07-29 07:00:25.811673+00	\N
344	benard		Access-Reject	2026-07-29 07:00:31.07152+00	\N
345	benard		Access-Reject	2026-07-29 07:00:36.330806+00	\N
346	benard		Access-Reject	2026-07-29 07:00:42.08667+00	\N
347	benard		Access-Reject	2026-07-29 07:00:47.557448+00	\N
348	benard		Access-Reject	2026-07-29 07:00:53.056749+00	\N
349	benard		Access-Reject	2026-07-29 07:00:58.281953+00	\N
350	benard		Access-Reject	2026-07-29 07:01:03.818848+00	\N
351	benard		Access-Reject	2026-07-29 07:01:09.276445+00	\N
352	benard		Access-Reject	2026-07-29 07:01:14.988942+00	\N
353	benard		Access-Reject	2026-07-29 07:01:20.837841+00	\N
354	benard		Access-Reject	2026-07-29 07:01:26.223287+00	\N
355	benard		Access-Reject	2026-07-29 07:01:31.543885+00	\N
356	benard		Access-Reject	2026-07-29 07:01:36.783709+00	\N
357	benard		Access-Reject	2026-07-29 07:01:42.158292+00	\N
358	benard		Access-Reject	2026-07-29 07:01:47.45427+00	\N
359	benard		Access-Reject	2026-07-29 07:01:53.033466+00	\N
360	benard		Access-Reject	2026-07-29 07:01:58.742562+00	\N
361	benard		Access-Reject	2026-07-29 07:02:04.088657+00	\N
362	benard		Access-Reject	2026-07-29 07:02:09.424723+00	\N
363	benard		Access-Reject	2026-07-29 07:02:15.054416+00	\N
364	benard		Access-Reject	2026-07-29 07:02:20.465407+00	\N
365	benard		Access-Reject	2026-07-29 07:02:26.153698+00	\N
366	benard		Access-Reject	2026-07-29 07:02:31.465707+00	\N
367	benard		Access-Reject	2026-07-29 07:02:36.765326+00	\N
368	benard		Access-Reject	2026-07-29 07:02:42.331437+00	\N
369	benard		Access-Reject	2026-07-29 07:02:47.871814+00	\N
370	benard		Access-Reject	2026-07-29 07:02:53.653541+00	\N
371	benard		Access-Reject	2026-07-29 07:02:59.161685+00	\N
372	benard		Access-Reject	2026-07-29 07:03:04.506898+00	\N
373	benard		Access-Reject	2026-07-29 07:03:10.231531+00	\N
374	benard		Access-Reject	2026-07-29 07:03:15.516219+00	\N
375	benard		Access-Reject	2026-07-29 07:03:21.011357+00	\N
376	benard		Access-Reject	2026-07-29 07:03:26.531356+00	\N
377	benard		Access-Reject	2026-07-29 07:03:31.827867+00	\N
378	benard		Access-Reject	2026-07-29 07:03:37.321887+00	\N
380	benard		Access-Reject	2026-07-29 07:03:48.553893+00	\N
382	benard		Access-Reject	2026-07-29 07:03:58.998272+00	\N
379	benard		Access-Reject	2026-07-29 07:03:42.713232+00	\N
381	benard		Access-Reject	2026-07-29 07:03:53.778956+00	\N
383	benard		Access-Reject	2026-07-29 07:04:04.308577+00	\N
384	3A:AD:23:80:40:76	RLMACAUTH	Access-Reject	2026-07-29 07:40:35.865346+00	\N
385	16:AA:15:6E:58:0B	RLMACAUTH	Access-Reject	2026-07-29 07:42:28.709559+00	\N
386	benard		Access-Accept	2026-07-29 07:47:39.215153+00	\N
387	benard		Access-Accept	2026-07-29 07:49:09.380781+00	\N
388	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-29 07:54:05.751932+00	\N
389	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-07-29 08:01:22.877363+00	\N
390	16:AA:15:6E:58:0B	RLMACAUTH	Access-Reject	2026-07-29 08:01:30.387315+00	\N
391	16:AA:15:6E:58:0B	RLMACAUTH	Access-Reject	2026-07-29 08:11:41.135314+00	\N
392	16:AA:15:6E:58:0B	RLMACAUTH	Access-Reject	2026-07-29 08:17:36.474759+00	\N
393	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 08:31:55.115868+00	\N
394	benard		Access-Accept	2026-07-29 08:38:47.313722+00	\N
395	3A:AD:23:80:40:76	RLMACAUTH	Access-Reject	2026-07-29 08:57:57.192924+00	\N
396	R4@44a1539e	y73a37	Access-Accept	2026-07-29 08:58:38.744534+00	\N
397	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 09:09:58.844822+00	\N
398	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 09:17:01.142742+00	\N
399	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 09:27:07.303695+00	\N
400	BC:2B:02:3A:7F:7C	RLMACAUTH	Access-Reject	2026-07-29 09:35:06.25723+00	\N
401	R3@44a1539e	d8ba64	Access-Accept	2026-07-29 10:10:00.514904+00	\N
402	R3@44a1539e	d8ba64	Access-Accept	2026-07-29 10:28:26.312139+00	\N
403	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Accept	2026-07-29 11:08:12.398385+00	\N
404	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 11:54:20.436908+00	\N
405	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 12:02:39.501633+00	\N
406	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 12:16:32.542515+00	\N
407	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 12:29:34.192842+00	\N
408	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-29 12:47:42.67644+00	\N
409	3A:AD:23:80:40:76	RLMACAUTH	Access-Reject	2026-07-29 12:48:54.424333+00	\N
410	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 12:48:57.102081+00	\N
411	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 13:42:46.376388+00	\N
412	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-29 13:53:29.400768+00	\N
413	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 14:07:20.551842+00	\N
414	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 14:20:26.044201+00	\N
415	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 14:45:01.361957+00	\N
416	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 15:04:27.869387+00	\N
417	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-29 16:50:51.873278+00	\N
418	66:87:6A:49:95:DA	RLMACAUTH	Access-Accept	2026-07-29 17:05:56.948606+00	\N
419	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 19:22:51.890386+00	\N
420	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 19:23:50.186343+00	\N
421	A6:0B:69:D9:3A:6D	RLMACAUTH	Access-Reject	2026-07-29 19:28:10.28285+00	\N
422	R7@44a1539e	xyd57b	Access-Accept	2026-07-29 19:29:08.182252+00	\N
423	CE:C4:E5:8C:D3:53	RLMACAUTH	Access-Reject	2026-07-29 19:30:20.742316+00	\N
424	R8@44a1539e	2373f4	Access-Accept	2026-07-29 19:30:59.582306+00	\N
425	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 19:36:50.380894+00	\N
426	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 19:50:23.507934+00	\N
427	72:5A:97:02:DC:D0	RLMACAUTH	Access-Reject	2026-07-29 19:53:15.69689+00	\N
428	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 19:59:12.734759+00	\N
429	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 20:11:13.1848+00	\N
430	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 20:22:00.472792+00	\N
431	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 20:30:25.8449+00	\N
432	A6:0B:69:D9:3A:6D	RLMACAUTH	Access-Reject	2026-07-29 20:35:35.684823+00	\N
433	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 20:36:43.696766+00	\N
434	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 20:48:36.264802+00	\N
435	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 20:57:15.264799+00	\N
436	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 21:09:13.147003+00	\N
437	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 21:21:29.164124+00	\N
438	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 21:33:43.46029+00	\N
439	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 21:43:51.463484+00	\N
440	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 22:00:08.593594+00	\N
441	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 22:09:43.634066+00	\N
442	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 22:21:14.024998+00	\N
443	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 22:26:58.136918+00	\N
444	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 22:33:46.195052+00	\N
445	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 22:46:29.858668+00	\N
446	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 23:16:31.131063+00	\N
447	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 23:23:23.682855+00	\N
448	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 23:34:10.252726+00	\N
449	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-29 23:52:23.350721+00	\N
450	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 00:08:19.513749+00	\N
451	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 00:13:52.411271+00	\N
452	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 00:22:02.705667+00	\N
453	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 00:33:28.647668+00	\N
454	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 00:46:56.887839+00	\N
455	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 00:56:04.750542+00	\N
456	CE:C4:E5:8C:D3:53	RLMACAUTH	Access-Reject	2026-07-30 00:59:42.573664+00	\N
457	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 01:03:58.481525+00	\N
458	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 01:15:24.855609+00	\N
459	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 01:22:41.43856+00	\N
460	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 01:31:14.382735+00	\N
461	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 01:39:44.104251+00	\N
462	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 01:49:06.053268+00	\N
463	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 01:50:04.132402+00	\N
464	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 01:55:33.373366+00	\N
465	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 02:04:29.317204+00	\N
466	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 02:10:47.916413+00	\N
467	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 02:16:25.794619+00	\N
468	9E:A0:95:3A:BF:8D	RLMACAUTH	Access-Reject	2026-07-30 02:21:56.650639+00	\N
\.


--
-- Data for Name: radreply; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.radreply (id, username, attribute, op, value) FROM stdin;
268	R2@44a1539e	Mikrotik-Rate-Limit	= 	10M/10M
12	R1@44a1539e	Mikrotik-Rate-Limit	= 	10M/10M
13	R1@44a1539e	Session-Timeout	= 	86351
4412	benard	Mikrotik-Rate-Limit	= 	5M/5M
4413	66:87:6A:49:95:DA	Session-Timeout	:=	14373
4414	66:87:6A:49:95:DA	Mikrotik-Rate-Limit	:=	10M/10M
1080	R5@44a1539e	Mikrotik-Rate-Limit	= 	5M/5M
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
87896a84-0d28-4b13-b3b0-7d1f7ef8c02e	44a1539e-4978-474e-987b-e817d98769f7	signup_bonus	50.0000	\N	\N	\N	\N	50.0000	\N	completed	Welcome bonus on signup	2026-07-29 06:14:50.346107+00
913da0eb-cb54-45ed-aaa5-7cc37fe66e25	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	49.0000	\N	completed	SMS sent	2026-07-29 06:16:03.908715+00
18127bff-1060-45d1-b01e-296b4aeb68ac	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	48.0000	\N	completed	SMS sent	2026-07-29 06:29:13.326512+00
c52e8f5f-82f2-4ee9-9615-10057182cddb	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	47.0000	\N	completed	SMS sent	2026-07-29 06:29:13.440333+00
a3924044-2cde-4f2e-806f-fd6f747eee99	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	46.0000	\N	completed	SMS sent	2026-07-29 06:30:00.981078+00
27a42d4e-07e3-439e-8a88-f9575b182872	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	45.0000	\N	completed	SMS sent	2026-07-29 08:58:35.50966+00
9ed8c2f2-7799-44b2-aaa8-78fc57b968a2	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	44.0000	\N	completed	SMS sent	2026-07-29 08:59:00.975147+00
14ddf715-f799-4e69-bb14-e9c7fcd7c0f6	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	43.0000	\N	completed	SMS sent	2026-07-29 09:39:01.001561+00
a84fc716-278c-4459-b99e-04f4495cc918	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	42.0000	\N	completed	SMS sent	2026-07-29 09:55:56.758967+00
12e91ddf-80b5-42f2-aec7-405c469c6bcf	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	41.0000	\N	completed	SMS sent	2026-07-29 10:10:01.196241+00
3f46fe22-112d-4251-a9dc-551192b7e8e7	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	40.0000	\N	completed	SMS sent	2026-07-29 10:14:15.872825+00
1f264c1f-2c58-48ee-ae9c-0eb9c15113b5	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	39.0000	\N	completed	SMS sent	2026-07-29 10:29:00.704444+00
6f9291b6-f7e1-4cab-96af-5fec2422cd10	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	38.0000	\N	completed	SMS sent	2026-07-29 10:34:00.854133+00
7fd86a87-d2b8-43cc-8fe7-cd56a2f71fd6	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	37.0000	\N	completed	SMS sent	2026-07-29 10:50:13.502644+00
61168c48-b028-453c-8dbc-ac8258ce9ca0	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	36.0000	\N	completed	SMS sent	2026-07-29 13:47:38.729449+00
232a3f06-b8c6-4484-87ef-b3fd122b86bb	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	35.0000	\N	completed	SMS sent	2026-07-29 15:11:20.325778+00
39c99cdb-b761-4b7f-9d84-21113b41ec5d	44a1539e-4978-474e-987b-e817d98769f7	consumption	-1.0000	\N	\N	\N	\N	34.0000	\N	completed	SMS sent	2026-07-29 15:20:02.802286+00
\.


--
-- Data for Name: sms_logs; Type: TABLE DATA; Schema: public; Owner: rumalink_user
--

COPY public.sms_logs (id, isp_id, recipient, message, gateway, gateway_message_id, status, cost, sent_at) FROM stdin;
a43d0dcd-a8c4-4ed8-a8f4-8913564bf82e	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Your RumaLink verification code is 258745. It expires in 10 minutes. Do not share it.	rumalink	\N	sent	\N	2026-07-29 06:16:03.911446+00
c6612f1d-3b53-4f9f-a062-26ede54ab73d	44a1539e-4978-474e-987b-e817d98769f7	254740258495	Your 24 Hours voucher: R1. Receipt: UGT130S7OJ\nValid until: 30 Jul 2026, 09:29\nReconnect if dropped: user R1 pass 6c53fe	rumalink	\N	sent	\N	2026-07-29 06:29:13.334913+00
4a0bb8fc-29f2-4152-80c5-efbf55969c6a	44a1539e-4978-474e-987b-e817d98769f7	254740258495	Your 24 Hours voucher: R1. Receipt: UGT130S7OJ\nValid until: 30 Jul 2026, 09:29\nReconnect if dropped: user R1 pass 6c53fe	rumalink	\N	sent	\N	2026-07-29 06:29:13.441992+00
4dde6c77-45a3-456c-8401-3c1c15f42725	44a1539e-4978-474e-987b-e817d98769f7	254740258495	Rumalink: 24 Hours activated.\nUsername: R1\nPassword: 6c53fe\nExpires: 30 Jul 2026, 09:29\nReceipt: UGT130S7OJ	rumalink	\N	sent	\N	2026-07-29 06:30:00.986525+00
775b7881-255a-467d-a5c5-dc2d1425f8a8	44a1539e-4978-474e-987b-e817d98769f7	254796829688	Your 1 Hour voucher: R4. Receipt: UGTJK0Q3I6\nValid until: 29 Jul 2026, 12:58\nReconnect if dropped: user R4 pass y73a37	rumalink	\N	sent	\N	2026-07-29 08:58:35.512194+00
866e5a47-e68d-48ec-95f0-8658f40471f8	44a1539e-4978-474e-987b-e817d98769f7	254796829688	Rumalink: 1 Hour activated.\nUsername: R4\nPassword: y73a37\nExpires: 29 Jul 2026, 12:58\nReceipt: UGTJK0Q3I6	rumalink	\N	sent	\N	2026-07-29 08:59:00.976951+00
a57d6f00-b2b0-4a5d-a85c-21767b07e281	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Rumalink: 24 Hours activated.\nUsername: R3\nPassword: d8ba64\nExpires: 30 Jul 2026, 12:38\nReceipt: UGTC80PNYY	rumalink	\N	sent	\N	2026-07-29 09:39:01.003675+00
98813db0-614e-480b-98dc-5b9fb894b9e8	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Rumalink: 24 Hours activated.\nUsername: R3\nPassword: d8ba64\nExpires: 30 Jul 2026, 12:54\nReceipt: UGTC80PQPY	rumalink	\N	sent	\N	2026-07-29 09:55:56.761095+00
0f3146ee-a7d9-4791-81fa-7fd55e82bd59	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Rumalink: 1 Hour activated.\nUsername: R3\nPassword: d8ba64\nExpires: 29 Jul 2026, 14:09\nReceipt: UGTC80PV35	rumalink	\N	sent	\N	2026-07-29 10:10:01.202179+00
421d5d2e-d4f6-4848-a964-360afc7bee0d	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Rumalink: 1 Hour activated.\nUsername: R3\nPassword: d8ba64\nExpires: 29 Jul 2026, 14:14\nReceipt: UGTC80PR44	rumalink	\N	sent	\N	2026-07-29 10:14:15.874834+00
b3f87515-3990-42cf-9915-f9a76f9d6c27	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Rumalink: 1 Hour activated.\nUsername: R3\nPassword: d8ba64\nExpires: 29 Jul 2026, 14:28\nReceipt: UGTC80PRDY	rumalink	\N	sent	\N	2026-07-29 10:29:00.706323+00
7c3b2c2d-3ed5-4c71-b55b-077032b1a857	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Rumalink: 1 Hour activated.\nUsername: R3\nPassword: d8ba64\nExpires: 29 Jul 2026, 14:33\nReceipt: UGTC80Q0R3	rumalink	\N	sent	\N	2026-07-29 10:34:00.855973+00
13fdb786-ba82-468d-a042-de9551b95e57	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Rumalink: 1 Hour activated.\nUsername: R6\nPassword: 3fdyeb\nExpires: 29 Jul 2026, 14:49\nReceipt: UGTC80PVVW	rumalink	\N	sent	\N	2026-07-29 10:50:13.504967+00
13754d08-5e71-4ead-a03d-5f3746684caa	44a1539e-4978-474e-987b-e817d98769f7	254117195942	Rumalink: 1 Hour activated for Benatv.\nIt connects automatically — no login needed.\nExpires: 29 Jul 2026, 17:46\nReceipt: UGTC80QKL2	rumalink	\N	sent	\N	2026-07-29 13:47:38.732015+00
ed9bc459-5151-4440-9cfd-f1f9552d5fc0	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 15:11, 29 Jul. You'll get another SMS when service is restored.	rumalink	\N	sent	\N	2026-07-29 15:11:20.327951+00
131343e4-41e1-43db-8038-0337e59e5059	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 15:20, 29 Jul. Outage lasted 8m.	rumalink	\N	sent	\N	2026-07-29 15:20:02.805669+00
104117ff-4449-4677-bf23-8033b140a422	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 17:24, 29 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 17:24:20.813173+00
f488002a-1853-452d-8b8d-62095cad77f8	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 19:23, 29 Jul. Outage lasted 1h 58m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 19:23:07.582764+00
f6af8c3d-644d-4974-a43a-4f5703681f50	44a1539e-4978-474e-987b-e817d98769f7	254758317799	Rumalink: 1 Hour activated.\nUsername: R7\nPassword: xyd57b\nExpires: 29 Jul 2026, 23:29\nReceipt: UGT391E2KW\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 19:30:00.615504+00
567c1172-44b5-4014-8369-8fcaa3a202ed	44a1539e-4978-474e-987b-e817d98769f7	254799596989	Rumalink: 1 Hour activated.\nUsername: R8\nPassword: 2373f4\nExpires: 29 Jul 2026, 23:30\nReceipt: UGTMT12RE6\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 19:31:00.616605+00
12df2a85-055f-447a-876f-6a725dff95c0	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 23:02, 29 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:02:19.967773+00
b17f5f8e-53a6-430d-94c0-1656cd59c9d1	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 23:03, 29 Jul. Outage lasted 0m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:03:05.280709+00
98b6dfff-379d-452f-8663-70da53ff3927	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 23:06, 29 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:06:17.904198+00
e1f4664c-fda7-4f94-a965-9fda938d4d92	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 23:07, 29 Jul. Outage lasted 0m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:07:10.225026+00
953ab323-83f7-4173-a145-3e5dfa50bf66	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 23:27, 29 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:27:18.844267+00
ca349fbd-0505-4ce3-9950-287ecc5322fa	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 23:34, 29 Jul. Outage lasted 6m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:34:02.855914+00
23dbd6e5-de9b-4a92-b3a8-d7714ebb7ce7	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 23:36, 29 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:36:20.299007+00
7b1f3c6c-18ec-41cb-b854-7edf3c2cec20	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 23:37, 29 Jul. Outage lasted 0m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:37:04.231988+00
4968f0ed-c228-4197-895d-15171d363698	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 23:49, 29 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:49:11.413711+00
c2e694cb-660c-486e-9ad8-9647e331d6ce	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 23:51, 29 Jul. Outage lasted 1m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:51:04.680554+00
de46620b-b152-4d90-9e2f-7d8cda096b78	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 23:53, 29 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:53:13.343512+00
c04899ec-adf6-4371-8814-a3771ec35e84	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 23:54, 29 Jul. Outage lasted 0m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-29 23:54:04.19219+00
5a651112-7e11-4095-b50e-81b41cb3c3a9	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 01:22, 30 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-30 01:22:20.404991+00
103952b0-efa5-4604-9d54-8fe6d0e13666	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 01:23, 30 Jul. Outage lasted 0m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-30 01:23:02.91345+00
11f20a7a-f3d7-48f1-b141-b7e505bad04d	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 01:49, 30 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-30 01:49:21.099447+00
51222313-a671-440f-8244-9930fa27ff03	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 01:54, 30 Jul. Outage lasted 4m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-30 01:54:03.87126+00
48cf2736-4d30-4f5e-95f0-66cc6c4aeca8	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 01:56, 30 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-30 01:56:20.290857+00
a2752133-8b5b-4be0-9df2-f15e0e6078db	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 02:01, 30 Jul. Outage lasted 4m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-30 02:01:09.295077+00
14fe198e-d178-4ef3-ac83-0a5c3598bcc6	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🔴 RumaLink Alert: Your MikroTik "DandoraP3" has LOST internet from its ISP provider at 02:10, 30 Jul. You'll get another SMS when service is restored.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-30 02:10:19.199583+00
081d8f48-c3d8-48d8-ada1-eaa6b4fa7ccf	44a1539e-4978-474e-987b-e817d98769f7	254117195942	🟢 RumaLink: Internet to "DandoraP3" has been RESTORED at 02:13, 30 Jul. Outage lasted 2m.\n[Request failed with status code 404]	rumalink	\N	failed	\N	2026-07-30 02:13:03.995194+00
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
-- Data for Name: usage_daily; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_daily (isp_id, device_id, username, usage_day, bytes_in, bytes_out, updated_at) FROM stdin;
44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	R4@44a1539e	2026-07-29	10176486	223084057	2026-07-29 09:26:01.468285+00
44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	9E:A0:95:3A:BF:8D	2026-07-29	132219	228166	2026-07-29 11:47:02.193446+00
44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	benard	2026-07-29	7212191	27373403	2026-07-29 12:53:01.890193+00
44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	R3@44a1539e	2026-07-29	14017051	17540117	2026-07-29 10:51:01.394449+00
44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	66:87:6A:49:95:DA	2026-07-29	33192369	155039556	2026-07-29 17:22:02.199592+00
44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	R7@44a1539e	2026-07-29	14473061	288617876	2026-07-29 20:30:02.406914+00
44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	R8@44a1539e	2026-07-29	34280396	373986072	2026-07-29 20:31:02.296029+00
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
1acfc5346827a0b04301c6965fd4a62a	8000005d	R3@44a1539e	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	13307901	16852632	2026-07-29 10:15:02.065705+00
28883bc969d70e489bf7477bec6c1c2d	80000057	R4@44a1539e	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	10176486	223084057	2026-07-29 09:28:02.425695+00
a20d7720f8a00d824a499a87cdc28f26	81100005	benard	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	25701698	58478399	2026-07-29 06:33:01.408196+00
7e2067c5d35dc4954d24f70c700f6516	8000005f	9E:A0:95:3A:BF:8D	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	132219	228166	2026-07-29 11:52:02.171263+00
ee4ba1e56248ab3ce95ea40ceeadf028	80100001	66:87:6A:49:95:DA	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	521975	1220568	2026-07-29 19:25:02.274589+00
d506b9d903206a6b1b62b7d621bb96e9	8100019d	benard	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	5106452	23771665	2026-07-29 12:55:01.28277+00
eb8b117b5b2efc87016eb61f2bb4fa55	80000064	66:87:6A:49:95:DA	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	133705	232257	2026-07-29 12:57:02.14257+00
e897534394b4d3f429606cb0ce7ce670	8000004d	66:87:6A:49:95:DA	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	31813310	151274672	2026-07-29 11:12:02.321374+00
debe399738eb8fdf9003beebeda5cd5a	8100019c	benard	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	1468830	170066	2026-07-29 08:41:02.041213+00
53c26b788b80183934173227cd126a81	80000068	66:87:6A:49:95:DA	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	18145	115100	2026-07-29 13:58:02.120686+00
28338f56ff55bb7ba4ab754e859d4ab8	80200003	R7@44a1539e	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	14473061	288617876	2026-07-29 20:32:01.221127+00
3c6a0770908bc7664bc0f3f136949954	8100019b	benard	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	636909	3431672	2026-07-29 07:52:01.581+00
d594acff72bb1ca3b723c2452d8bc627	80200005	R8@44a1539e	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	34280396	373986072	2026-07-29 20:33:02.16223+00
7a585fa0fb24ab8153e7071f288a61eb	80100000	66:87:6A:49:95:DA	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	705234	2196959	2026-07-29 16:57:01.625869+00
2f65a8618b2271d34c63cd8cf45621d4	8000005e	R3@44a1539e	44a1539e-4978-474e-987b-e817d98769f7	0cc4baf5-a5d0-402c-b350-ba48fbc1a4a1	709150	687485	2026-07-29 10:53:02.050059+00
\.


--
-- Data for Name: verification_codes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_codes (id, isp_id, channel, target, code_hash, expires_at, attempts, consumed_at, ip, created_at, selector) FROM stdin;
1	44a1539e-4978-474e-987b-e817d98769f7	email	rumalinkenterprise@gmail.com	fe09ecb19f656fcc.ecdb8b915492b433fbb9e948eb0053658b44a4e17a1f933761ddced0363cb19d	2026-07-30 06:14:51.412046+00	0	2026-07-29 06:15:48.30847+00	102.205.237.69	2026-07-29 06:14:51.412046+00	a428c2c1518b
2	44a1539e-4978-474e-987b-e817d98769f7	phone	254117195942	1bc746d48dc030ec.62cf0e12656207bcf3d415b05ce6393809922e623b644996caf8d11399e1c833	2026-07-29 06:26:03.723322+00	0	2026-07-29 06:17:03.276036+00	102.205.237.69	2026-07-29 06:16:03.723322+00	\N
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

SELECT pg_catalog.setval('public.radacct_radacctid_seq', 16, true);


--
-- Name: radcheck_delete_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.radcheck_delete_audit_id_seq', 102, true);


--
-- Name: radcheck_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radcheck_id_seq', 45, true);


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

SELECT pg_catalog.setval('public.radpostauth_id_seq', 468, true);


--
-- Name: radreply_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rumalink_user
--

SELECT pg_catalog.setval('public.radreply_id_seq', 4414, true);


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

\unrestrict hjXVT7uhDNJHE1ItaCEyyylG9aN2C1agEueGZRAwUs5J8VrH65kOgxQvMbposLg

