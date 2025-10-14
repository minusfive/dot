import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import {
  validateMarkdownFile,
  type ValidationResult,
} from "./validate-markdown";
import { unlink } from "node:fs/promises";

describe("validate-markdown script", () => {
  const testFiles: string[] = [];

  // Helper to create and track test files
  const createTestFile = async (
    filename: string,
    content: string,
  ): Promise<string> => {
    const testFile = `/tmp/${filename}`;
    await Bun.write(testFile, content);
    testFiles.push(testFile);
    return testFile;
  };

  // Clean up test files after each test
  afterEach(async () => {
    for (const file of testFiles) {
      try {
        await unlink(file);
      } catch {
        // Ignore cleanup errors
      }
    }
    testFiles.length = 0;
  });

  describe("CLI interface", () => {
    it("should validate a simple markdown file", async () => {
      const testContent = `# Test Document

## Section 1

This is a test.

- Item 1
- Item 2

\`\`\`typescript
console.log("test");
\`\`\`
`;

      const testFile = await createTestFile("test-markdown.md", testContent);

      const result = Bun.spawnSync(
        ["bun", "run", "./validate-markdown.ts", testFile],
        {
          cwd: import.meta.dir,
        },
      );

      expect(result.exitCode).toBe(0);
      expect(result.stdout.toString()).toContain("✅ Validation passed");
    });

    it("should detect heading hierarchy errors", async () => {
      const testContent = `# Test Document

### Invalid Jump

This jumps from H1 to H3.
`;

      const testFile = await createTestFile("test-invalid.md", testContent);

      const result = Bun.spawnSync(
        ["bun", "run", "./validate-markdown.ts", testFile],
        {
          cwd: import.meta.dir,
        },
      );

      expect(result.exitCode).toBe(1);
      expect(result.stdout.toString()).toContain("❌ Validation failed");
      expect(result.stdout.toString()).toContain(
        "Heading level H3 jumps from H1",
      );
    });

    it("should detect list formatting issues", async () => {
      const testContent = `# Test Document

* Bad list item
* Another bad item

- Good list item
`;

      const testFile = await createTestFile("test-lists.md", testContent);

      const result = Bun.spawnSync(
        ["bun", "run", "./validate-markdown.ts", testFile],
        {
          cwd: import.meta.dir,
        },
      );

      expect(result.exitCode).toBe(0); // Warnings don't fail
      expect(result.stdout.toString()).toContain(
        "Use hyphens (-) for unordered lists",
      );
      expect(result.stdout.toString()).toContain("Warnings: 2");
    });

    it("should detect code blocks without language", async () => {
      const testContent = `# Test Document

\`\`\`
console.log("no language specified");
\`\`\`

\`\`\`javascript
console.log("language specified");
\`\`\`
`;

      const testFile = await createTestFile("test-codeblocks.md", testContent);

      const result = Bun.spawnSync(
        ["bun", "run", "./validate-markdown.ts", testFile],
        {
          cwd: import.meta.dir,
        },
      );

      expect(result.exitCode).toBe(0); // Warnings don't fail
      expect(result.stdout.toString()).toContain(
        "Specify language for code blocks",
      );
      expect(result.stdout.toString()).toContain("Warnings: 1");
    });

    it("should detect anchor links", async () => {
      const testContent = `# Test Document

See [this section](#section-1) for details.

## Section 1

Content here.
`;

      const testFile = await createTestFile("test-anchors.md", testContent);

      const result = Bun.spawnSync(
        ["bun", "run", "./validate-markdown.ts", testFile],
        {
          cwd: import.meta.dir,
        },
      );

      expect(result.exitCode).toBe(0);
      expect(result.stdout.toString()).toContain("Found anchor links");
      expect(result.stdout.toString()).toContain("#section-1");
    });

    it("should handle file not found error", async () => {
      const result = Bun.spawnSync(
        ["bun", "run", "./validate-markdown.ts", "/tmp/nonexistent.md"],
        {
          cwd: import.meta.dir,
        },
      );

      expect(result.exitCode).toBe(1);
      expect(result.stderr.toString()).toContain("File does not exist");
    });

    it("should require file argument", async () => {
      const result = Bun.spawnSync(["bun", "run", "./validate-markdown.ts"], {
        cwd: import.meta.dir,
      });

      expect(result.exitCode).toBe(1);
      expect(result.stderr.toString()).toContain(
        "Usage: bun run validate-markdown.ts",
      );
    });
  });

  describe("validateMarkdownFile function", () => {
    it("should validate perfect markdown", async () => {
      const testContent = `# Main Title

## Section 1

- Proper list item
- Another item

\`\`\`typescript
const code = "with language";
\`\`\`

## Section 2

More content.
`;

      const testFile = await createTestFile("perfect.md", testContent);

      // Capture console output
      const originalLog = console.log;
      const logs: string[] = [];
      console.log = (msg: string) => logs.push(msg);

      try {
        const result = await validateMarkdownFile(testFile);
        expect(result.errors).toBe(0);
        expect(result.warnings).toBe(0);
        expect(logs.join(" ")).toContain("✅ Heading hierarchy is correct");
        expect(logs.join(" ")).toContain("✅ List formatting is consistent");
        expect(logs.join(" ")).toContain(
          "✅ All code blocks specify languages",
        );
      } finally {
        console.log = originalLog;
      }
    });

    it("should validate multiple heading hierarchy violations", async () => {
      const testContent = `# Title

### Skip H2

#### Skip to H4

# Back to H1

### Another skip
`;

      const testFile = await createTestFile(
        "multi-heading-errors.md",
        testContent,
      );

      // Capture console output
      const originalLog = console.log;
      const logs: string[] = [];
      console.log = (msg: string) => logs.push(msg);

      try {
        const result = await validateMarkdownFile(testFile);
        expect(result.errors).toBeGreaterThan(0);
        expect(logs.join(" ")).toContain("Heading level H3 jumps from H1");
      } finally {
        console.log = originalLog;
      }
    });

    it("should handle empty files", async () => {
      const testFile = await createTestFile("empty.md", "");

      const originalLog = console.log;
      const logs: string[] = [];
      console.log = (msg: string) => logs.push(msg);

      try {
        const result = await validateMarkdownFile(testFile);
        expect(result.errors).toBe(0);
        expect(result.warnings).toBe(0);
      } finally {
        console.log = originalLog;
      }
    });

    it("should validate mixed formatting issues", async () => {
      const testContent = `# Title

* Bad asterisk list
- Good hyphen list
* Another asterisk

\`\`\`
no language
\`\`\`

[Anchor link](#some-section)
`;

      const testFile = await createTestFile("mixed-issues.md", testContent);

      const originalLog = console.log;
      const logs: string[] = [];
      console.log = (msg: string) => logs.push(msg);

      try {
        const result = await validateMarkdownFile(testFile);
        expect(result.errors).toBe(0);
        expect(result.warnings).toBe(3); // 2 asterisk + 1 code block
        expect(logs.join(" ")).toContain("Use hyphens (-) for unordered lists");
        expect(logs.join(" ")).toContain("Specify language for code blocks");
        expect(logs.join(" ")).toContain("Found anchor links");
      } finally {
        console.log = originalLog;
      }
    });

    it("should handle files with only whitespace", async () => {
      const testFile = await createTestFile("whitespace.md", "   \n\n\t  \n  ");

      const originalLog = console.log;
      const logs: string[] = [];
      console.log = (msg: string) => logs.push(msg);

      try {
        const result = await validateMarkdownFile(testFile);
        expect(result.errors).toBe(0);
        expect(result.warnings).toBe(0);
      } finally {
        console.log = originalLog;
      }
    });
  });

  describe("Integration tests", () => {
    it("should validate project AGENTS.md file", async () => {
      const agentsPath = "../../AGENTS.md";

      const result = Bun.spawnSync(
        ["bun", "run", "./validate-markdown.ts", agentsPath],
        {
          cwd: import.meta.dir,
        },
      );

      // AGENTS.md should be well-formatted
      expect(result.exitCode).toBe(0);
      expect(result.stdout.toString()).toContain(
        "MARKDOWN VALIDATION: AGENTS.md",
      );
    });

    it("should validate README files", async () => {
      const readmePath = "../../README.md";

      const result = Bun.spawnSync(
        ["bun", "run", "./validate-markdown.ts", readmePath],
        {
          cwd: import.meta.dir,
        },
      );

      expect(result.stdout.toString()).toContain(
        "MARKDOWN VALIDATION: README.md",
      );
      // Don't assert exit code as README might have warnings
    });
  });

  describe("Edge cases", () => {
    it("should handle very long files efficiently", async () => {
      const longContent = Array(1000)
        .fill("# Heading\n\nContent paragraph.\n\n")
        .join("");
      const testFile = await createTestFile("long-file.md", longContent);

      const startTime = Date.now();

      const originalLog = console.log;
      console.log = () => {}; // Suppress output for performance test

      try {
        await validateMarkdownFile(testFile);
        const duration = Date.now() - startTime;
        expect(duration).toBeLessThan(1000); // Should complete within 1 second
      } finally {
        console.log = originalLog;
      }
    });

    it("should handle complex anchor patterns", async () => {
      const testContent = `# Test

[Simple anchor](#simple)
[Complex anchor](#complex-section-with-numbers-123)
[Invalid anchor](#Invalid-Caps)

## Simple

## Complex Section with Numbers 123
`;

      const testFile = await createTestFile("complex-anchors.md", testContent);

      const originalLog = console.log;
      const logs: string[] = [];
      console.log = (msg: string) => logs.push(msg);

      try {
        const result = await validateMarkdownFile(testFile);
        expect(logs.join(" ")).toContain("Found anchor links");
        expect(logs.join(" ")).toContain("#simple");
        expect(logs.join(" ")).toContain("#complex-section-with-numbers-123");
        expect(logs.join(" ")).toContain("#Invalid-Caps");
      } finally {
        console.log = originalLog;
      }
    });

    it("should handle nested and indented lists", async () => {
      const testContent = `# Test

- Good list
  - Nested good
  * Nested bad asterisk
- Another good
* Top level bad

1. Ordered list
   * Mixed bad asterisk
   - Mixed good hyphen
`;

      const testFile = await createTestFile("nested-lists.md", testContent);

      const originalLog = console.log;
      const logs: string[] = [];
      console.log = (msg: string) => logs.push(msg);

      try {
        const result = await validateMarkdownFile(testFile);
        expect(result.warnings).toBe(3); // 3 asterisk uses
        expect(logs.join(" ")).toContain("Use hyphens (-) for unordered lists");
      } finally {
        console.log = originalLog;
      }
    });
  });
});
