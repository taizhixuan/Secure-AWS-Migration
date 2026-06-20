<?php
/*
 * Lightweight liveness endpoint for the ALB target group health check.
 * Deliberately does NOT touch the database so transient DB latency does not
 * cause healthy tasks to be marked unhealthy and recycled.
 */
http_response_code(200);
header('Content-Type: text/plain');
echo 'OK';
