#include <keymaster/android_keymaster_messages.h>

extern "C" {
/* The vendor begonia keymaster@4.0 blobs were built against these three
 * symbols from the older libkeymaster_messages ABI. Keep the shim narrow:
 * interposing the complete keymaster message ABI can break PBRP's own
 * libkeymaster_messages implementation. */
void _ZN9keymaster19GenerateKeyResponseD1Ev() {}
void _ZN9keymaster17AttestKeyResponseD1Ev() {}
void _ZN9keymaster16ImportKeyRequest14SetKeyMaterialEPKvm(
        keymaster::ImportKeyRequest* thisptr,
        const uint8_t* key_material,
        size_t length) {
    thisptr->key_data = keymaster::KeymasterKeyBlob(key_material, length);
}
}
