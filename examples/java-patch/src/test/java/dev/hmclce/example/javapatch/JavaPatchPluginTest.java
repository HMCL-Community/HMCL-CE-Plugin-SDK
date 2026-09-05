package dev.hmclce.example.javapatch;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.jackhuang.hmcl.plugin.PluginPatchDeclaration;
import org.jackhuang.hmcl.plugin.PluginPatchInvocation;
import org.jackhuang.hmcl.plugin.PluginPatchResult;
import org.jetbrains.annotations.NotNullByDefault;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;

/// Verifies the Java Patch example's declared observational callback behavior.
@NotNullByDefault
final class JavaPatchPluginTest {
    /// Ensures the manifest declaration produces an `after` invocation whose null result is preserved.
    @Test
    void returnsUnchangedForTheDeclaredAfterCallbackWithANullResult() throws IOException {
        JsonObject manifest = JsonParser.parseString(Files.readString(Path.of("plugin.json"))).getAsJsonObject();
        JsonObject patch = manifest.getAsJsonArray("patches").get(0).getAsJsonObject();
        String patchType = patch.get("type").getAsString();
        assertEquals("after", patchType);
        JsonArray parameters = patch.getAsJsonArray("parameters");
        List<String> parameterNames = new ArrayList<>();
        for (int index = 0; index < parameters.size(); index++) {
            parameterNames.add(parameters.get(index).getAsString());
        }
        PluginPatchDeclaration declaration = new PluginPatchDeclaration(
                patch.get("target").getAsString(),
                patch.get("method").getAsString(),
                PluginPatchDeclaration.PatchType.valueOf(patchType.toUpperCase(Locale.ROOT)),
                parameterNames);
        List<Object> arguments = new ArrayList<>(List.of(Path.of("example.txt")));

        PluginPatchResult result = new JavaPatchPlugin().onPatch(
                PluginPatchInvocation.after(declaration, null, arguments, null));

        assertSame(PluginPatchResult.unchanged(), result);
        assertEquals(List.of(Path.of("example.txt")), arguments);
    }
}
