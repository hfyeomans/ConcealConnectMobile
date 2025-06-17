#pragma once
/*
 *  masque.h
 *  Public C interface for Conceal’s MASQUE-over-QUIC client
 *
 *  This header deliberately exposes only the symbols the iOS wrapper needs.
 *  All functions are thin wrappers around Cloudflare quiche APIs.
 */

#include <stdint.h>     /* uint8_t, uint64_t */
#include <stddef.h>     /* size_t            */
#include <sys/types.h>  /* ssize_t           */
#include <stdbool.h>    /* bool              */

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------
 *  Forward declarations (from quiche)
 * ---------------------------------------------------------------------- */
typedef struct quiche_conn quiche_conn;

// Forward declare these structs for the passthrough functions
struct quiche_recv_info;
struct quiche_send_info;

/* -------------------------------------------------------------------------
 *  Conceal wrapper API
 * ---------------------------------------------------------------------- */

/**
 * Establish a MASQUE-over-QUIC connection.
 *
 * @param scid         20-byte client-chosen source connection ID.
 * @param scid_len     Length of @p scid (must be 20).
 * @param server_name  Remote SNI / IP string.
 * @param port         Remote port (usually 443).
 *
 * @return A pointer to an active quiche_conn on success, or NULL on failure.
 */
quiche_conn *conceal_masque_connect(const uint8_t *scid,
                                    size_t         scid_len,
                                    const char    *server_name,
                                    uint16_t       port);

/**
 * Allocate a unidirectional stream ID.
 *
 * @return Stream ID on success, or UINT64_MAX on error.
 */
uint64_t conceal_masque_stream_new(quiche_conn *conn);

/**
 * Send a buffer on @p stream_id.  Finalises the stream (fin=true).
 *
 * @return Bytes written (>=0) or a negative quiche error code.
 */
ssize_t conceal_masque_send(quiche_conn *conn,
                            uint64_t     stream_id,
                            const uint8_t *buf,
                            size_t        len);

/**
 * Poll the connection for readable streams.
 *
 * Reads at most @p buf_len bytes from the first readable stream into @p out_buf.
 *
 * @return The stream ID that produced data, or UINT64_MAX if nothing readable.
 */
uint64_t conceal_masque_poll(quiche_conn *conn,
                             uint8_t     *out_buf,
                             size_t       buf_len);

/* -------------------------------------------------------------------------
 *  Direct passthrough symbols needed by the UDP driver (unit tests only)
 * ---------------------------------------------------------------------- */

/**
 * Feed a received UDP datagram into quiche.
 */
ssize_t quiche_conn_recv(quiche_conn *conn, uint8_t *buf, size_t buf_len,
                         const struct quiche_recv_info *info);

/**
 * Write packets to be sent on the wire.
 */
ssize_t quiche_conn_send(quiche_conn *conn, uint8_t *out, size_t out_len,
                         struct quiche_send_info *out_info);

/**
 * Check if the QUIC handshake has completed.
 */
bool quiche_conn_is_established(quiche_conn *conn);

#ifdef __cplusplus
} /* extern "C" */
#endif
