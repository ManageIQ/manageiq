--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: test; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE test (
    id bigint NOT NULL,
    data character varying,
    uuid character varying
);


ALTER TABLE test OWNER TO root;

--
-- Name: test_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE test_id_seq OWNER TO root;

--
-- Name: test_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE test_id_seq OWNED BY test.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE ONLY test ALTER COLUMN id SET DEFAULT nextval('test_id_seq'::regclass);


--
-- Name: test_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY test
    ADD CONSTRAINT test_pkey PRIMARY KEY (id);


--
-- Name: test_uuid_unique; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY test
    ADD CONSTRAINT test_uuid_unique UNIQUE (uuid);


--
-- PostgreSQL database dump complete
--

