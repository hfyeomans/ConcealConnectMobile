#include "../masquelib/quiche/include/quiche.h"
#include "../include/masque.h"
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

/* ---------- helpers ---------------------------------------------------- */

static uint64_t next_uni_stream_id = 2;  // Client-initiated unidirectional streams start at 2

static quiche_config *default_cfg(void) {
    static quiche_config *cfg;
    if (cfg) return cfg;

    cfg = quiche_config_new(0xbabababa);
    quiche_config_set_application_protos(
        cfg,
        (uint8_t *)"\x05hq-29\x05hq-30\x05hq-31",
        18 /* length of the above blob */
    );
    quiche_config_set_max_idle_timeout(cfg, 15000);
    quiche_config_enable_early_data(cfg);
    return cfg;
}

/* ---------- public API -------------------------------------------------- */

quiche_conn *
conceal_masque_connect(const uint8_t *scid,
                       size_t         scid_len,
                       const char    *server_name,
                       uint16_t       port)
{
    // Create socket addresses
    struct sockaddr_storage local_addr = {0};
    struct sockaddr_storage peer_addr = {0};
    
    // For now, use dummy addresses - real implementation would resolve server_name
    struct sockaddr_in *local_in = (struct sockaddr_in *)&local_addr;
    local_in->sin_family = AF_INET;
    local_in->sin_port = 0;  // Let OS choose port
    
    struct sockaddr_in *peer_in = (struct sockaddr_in *)&peer_addr;
    peer_in->sin_family = AF_INET;
    peer_in->sin_port = htons(port);
    peer_in->sin_addr.s_addr = htonl(INADDR_LOOPBACK); // 127.0.0.1 for testing

    return quiche_connect(server_name, scid, scid_len, 
                         (struct sockaddr *)&local_addr, sizeof(struct sockaddr_in),
                         (struct sockaddr *)&peer_addr, sizeof(struct sockaddr_in),
                         default_cfg());
}

uint64_t conceal_masque_stream_new(quiche_conn *conn) {
    if (!conn) return UINT64_MAX;
    
    // Check if we can create a new stream
    if (quiche_conn_stream_capacity(conn, next_uni_stream_id) > 0) {
        uint64_t stream_id = next_uni_stream_id;
        next_uni_stream_id += 4;  // Client uni streams: 2, 6, 10, 14, ...
        return stream_id;
    }
    
    return UINT64_MAX;
}

ssize_t conceal_masque_send(quiche_conn *conn,
                            uint64_t     sid,
                            const uint8_t *buf,
                            size_t        len)
{
    uint64_t error_code = 0;
    return quiche_conn_stream_send(conn, sid, buf, len, /*fin=*/true, &error_code);
}

uint64_t conceal_masque_poll(quiche_conn *conn,
                             uint8_t     *out_buf,
                             size_t       buf_len)
{
    quiche_stream_iter *it = quiche_conn_readable(conn);
    uint64_t sid = UINT64_MAX;

    if (quiche_stream_iter_next(it, &sid)) {
        bool fin = false;
        uint64_t error_code = 0;
        quiche_conn_stream_recv(conn, sid, out_buf, buf_len, &fin, &error_code);
    }
    quiche_stream_iter_free(it);
    return sid;
}
