# ISLKey `.islkey` Config Export — WordPress Integration

This adds a **Download .islkey Config File** button to the ISLKey provisioning-token
screen. The file is plain JSON consumed by the ISLKey Flasher's **Load .islkey File**
button. It is mechanism-agnostic — it only emits config; the flasher writes it to the
device over the commissioning serial link.

> The ISLKey WordPress plugin is **not part of this workspace** (it lives on the
> customer's site), so these changes are provided as drop-in snippets to merge into
> your `isl-key` plugin. They match the schema the new flasher expects.

Files to edit in the `isl-key` plugin:
- `admin/class-islkey-admin.php`
- `admin/views/devices.php`

---

## 1. `admin/class-islkey-admin.php`

### 1a — Register the handler (in `init()`, beside the other `admin_post` handlers)

```php
add_action( 'admin_post_islkey_download_config', array( __CLASS__, 'handle_download_config' ) );
```

### 1b — Store `board_type` when a token is generated

In `handle_generate_token()`, after:
```php
$expiry_hours = (int) ( $_POST['expiry_hours'] ?? 24 );
```
add:
```php
$board_type = sanitize_key( $_POST['board_type'] ?? 'relay-board' );
```
and add `board_type` to the existing `set_transient( 'islkey_fresh_token_' . get_current_user_id(), [...] )` array:
```php
'board_type' => $board_type,
```

### 1c — Add the download handler method (after `handle_generate_token()`)

```php
public static function handle_download_config() {
    check_admin_referer( 'islkey_download_config' );
    if ( ! current_user_can( 'manage_options' ) ) wp_die( 'Forbidden' );

    global $wpdb;

    $token       = sanitize_text_field( $_POST['token']       ?? '' );
    $customer_id = (int) ( $_POST['customer_id'] ?? 0 );
    $board_type  = sanitize_key( $_POST['board_type'] ?? 'relay-board' );

    // Validate token: exists, belongs to this customer, unconsumed, unexpired
    $pt = $wpdb->get_row( $wpdb->prepare(
        "SELECT * FROM `{$wpdb->prefix}islkey_provisioning_tokens`
         WHERE token = %s AND customer_id = %d AND consumed = 0 AND expires_at > NOW()",
        $token, $customer_id
    ) );
    if ( ! $pt ) {
        wp_die( 'Token not found, already consumed, or expired.' );
    }

    $door      = $pt->door_id ? ISLKey_Doors::get( $pt->door_id, $customer_id ) : null;
    $site      = ISLKey_Sites::get( $pt->site_id, $customer_id );
    $site_code = $site ? ( $site->site_code ?? sanitize_key( $site->site_name ) ) : '';

    $current_user = wp_get_current_user();

    $config = array(
        'islkey_config_version' => '1.0',
        'generated_at'          => gmdate( 'Y-m-d\TH:i:s\Z' ),
        'generated_by'          => 'ISL Admin — ' . $current_user->user_email,
        'expires_at'            => gmdate( 'Y-m-d\TH:i:s\Z', strtotime( $pt->expires_at ) ),

        'api' => array(
            'url'   => untrailingslashit( get_site_url() ),
            'token' => $token,
        ),

        'device' => array(
            'serial_number' => '',   // Flasher assigns from its own counter at flash time
            'board_type'    => $board_type,
            'door_name'     => $door ? $door->door_name : ( $site ? $site->site_name . ' Door' : 'Door' ),
            'site_name'     => $site ? $site->site_name : '',
            'site_code'     => $site_code,
            'door_id'       => $pt->door_id ? (int) $pt->door_id : 0,
            'site_id'       => $pt->site_id ? (int) $pt->site_id : 0,
            'customer_id'   => (int) $customer_id,
            'zone'          => $door ? ( $door->zone ?? '' ) : '',
        ),

        // Sensible defaults. The current device firmware applies api/door/site from
        // this file at commissioning; inputs/relays/door_behaviour use firmware
        // defaults and are overridable on the device provisioning page. (Panic input
        // types 5–7 require the separate "Protocols" firmware build.)
        'inputs' => array(
            'input_1_function' => 1, 'input_1_logic' => 1,
            'input_2_function' => 2, 'input_2_logic' => 0,
            'input_3_function' => 5, 'input_3_logic' => 1,
            'input_4_function' => 6, 'input_4_logic' => 1,
        ),
        'relays' => array(
            'relay_1_function' => 1, 'relay_1_pulse_ms' => 5000, 'relay_1_active_high' => true,
            'relay_2_function' => 0, 'relay_2_pulse_ms' => 2000, 'relay_2_active_high' => true,
        ),
        'door_behaviour' => array(
            'held_open_secs' => 60, 'forced_entry_detect' => true,
        ),
    );

    $safe_door = preg_replace( '/[^a-zA-Z0-9]+/', '', str_replace( ' ', '', $config['device']['door_name'] ) );
    $safe_site = preg_replace( '/[^a-zA-Z0-9]+/', '', str_replace( ' ', '', $config['device']['site_code'] ?: $config['device']['site_name'] ) );
    $filename  = "ISLKey-{$safe_site}-{$safe_door}-" . date( 'Ymd' ) . ".islkey";

    nocache_headers();
    header( 'Content-Type: application/json; charset=utf-8' );
    header( 'Content-Disposition: attachment; filename="' . $filename . '"' );
    header( 'X-Content-Type-Options: nosniff' );
    echo wp_json_encode( $config, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES );
    exit;
}
```

---

## 2. `admin/views/devices.php`

### 2a — Board-type selector in the Generate-Token form (before the submit button)

```php
<tr>
    <th>Board Type</th>
    <td>
        <select name="board_type" class="regular-text">
            <option value="relay-board">ISLKey Relay Board (WROOM dual relay)</option>
            <option value="devkit">ESP32 DevKit V1 (testing)</option>
            <option value="ttgo">TTGO T-Display (with LCD)</option>
            <option value="wt32-eth01">WT32-ETH01 (Ethernet + PoE)</option>
        </select>
    </td>
</tr>
```

### 2b — Download button in the fresh-token panel (after the "Device API Token" row)

```php
<tr>
    <th>Config File</th>
    <td>
        <form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" style="display:inline;">
            <?php wp_nonce_field( 'islkey_download_config' ); ?>
            <input type="hidden" name="action"      value="islkey_download_config">
            <input type="hidden" name="token"       value="<?php echo esc_attr( $fresh_token['token'] ); ?>">
            <input type="hidden" name="customer_id" value="<?php echo esc_attr( $customer_id ); ?>">
            <input type="hidden" name="board_type"  value="<?php echo esc_attr( $fresh_token['board_type'] ?? 'relay-board' ); ?>">
            <button type="submit" class="button button-primary">⬇ Download .islkey Config File</button>
        </form>
        <p class="description">
            Load this file into the ISLKey Flasher. It pre-populates board type, API URL,
            token, door name and site code — only WiFi is entered on the device.
        </p>
    </td>
</tr>
```

---

## Notes for the new firmware/flasher

- `device.serial_number` is intentionally `""` — the flasher assigns the serial from its
  local counter (`serials/next-serial.txt`) at flash time and logs it to the asset register.
- The flasher writes `api.url`, `api.token`, `device.door_name`, `device.site_code` (plus the
  generated serial + AP password) to the device over the serial commissioning link
  (`ISLKEY-PROV:{json}` → `ISLKEY-ACK`). The device stores them in NVS and pre-fills its
  provisioning page, so the installer only enters WiFi SSID + password.
- This export does **not** use the old `buildNVSImage` / `checkFlasherPayload` path from the
  v1.0 build guide — that was for the previous firmware and has been superseded.
