import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.HexFormat;

/** Minimal Java 17 Ed25519 helper used by the PowerShell publishing tools. */
public final class HmclCeSigner {
    /** Runs one key generation, key-ID, signing, or verification command. */
    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            usage();
        }
        switch (args[0]) {
            case "generate" -> {
                requireArgs(args, 3);
                KeyPair pair = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
                writeBase64(Path.of(args[1]), pair.getPrivate().getEncoded());
                writeBase64(Path.of(args[2]), pair.getPublic().getEncoded());
                System.out.println(keyId(pair.getPublic().getEncoded()));
            }
            case "key-id" -> {
                requireArgs(args, 2);
                System.out.println(keyId(readBase64(Path.of(args[1]))));
            }
            case "sign" -> {
                requireArgs(args, 3);
                PrivateKey key = KeyFactory.getInstance("Ed25519").generatePrivate(
                        new PKCS8EncodedKeySpec(readBase64(Path.of(args[1])))
                );
                Signature signer = Signature.getInstance("Ed25519");
                signer.initSign(key);
                signer.update(Files.readAllBytes(Path.of(args[2])));
                System.out.println(Base64.getEncoder().encodeToString(signer.sign()));
            }
            case "verify" -> {
                requireArgs(args, 4);
                PublicKey key = KeyFactory.getInstance("Ed25519").generatePublic(
                        new X509EncodedKeySpec(readBase64(Path.of(args[1])))
                );
                Signature verifier = Signature.getInstance("Ed25519");
                verifier.initVerify(key);
                verifier.update(Files.readAllBytes(Path.of(args[2])));
                if (!verifier.verify(Base64.getDecoder().decode(args[3]))) {
                    throw new SecurityException("Ed25519 signature verification failed");
                }
                System.out.println("Signature verified.");
            }
            default -> usage();
        }
    }

    /** Writes one Base64 key file; callers remain responsible for filesystem access controls. */
    private static void writeBase64(Path path, byte[] value) throws Exception {
        Path parent = path.toAbsolutePath().getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }
        Files.writeString(path, Base64.getEncoder().encodeToString(value) + "\n", StandardCharsets.US_ASCII);
    }

    /** Reads one whitespace-tolerant Base64 key file. */
    private static byte[] readBase64(Path path) throws Exception {
        return Base64.getDecoder().decode(Files.readString(path, StandardCharsets.US_ASCII).replaceAll("\\s", ""));
    }

    /** Computes the HMCL CE key ID from an X.509 SubjectPublicKeyInfo value. */
    private static String keyId(byte[] encodedPublicKey) throws Exception {
        return "ed25519:" + HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(encodedPublicKey)
        );
    }

    /** Requires an exact command argument count. */
    private static void requireArgs(String[] args, int count) {
        if (args.length != count) {
            usage();
        }
    }

    /** Prints command syntax and exits with an error. */
    private static void usage() {
        throw new IllegalArgumentException("Usage: HmclCeSigner.java "
                + "generate <private.pk8.b64> <public.spki.b64> | "
                + "key-id <public.spki.b64> | sign <private.pk8.b64> <payload> | "
                + "verify <public.spki.b64> <payload> <signature-base64>");
    }

    /** Prevents construction. */
    private HmclCeSigner() {
    }
}
