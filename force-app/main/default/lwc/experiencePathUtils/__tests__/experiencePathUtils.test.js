import { ensureSitePath } from "c/experiencePathUtils";

describe("experiencePathUtils", () => {
  test("ensureSitePath returns slash for falsy path", () => {
    expect(ensureSitePath("")).toBe("/");
    expect(ensureSitePath(null)).toBe("/");
    expect(ensureSitePath(undefined)).toBe("/");
  });

  test("ensureSitePath normalizes leading slash", () => {
    expect(ensureSitePath("tasks")).toBe("/tasks");
    expect(ensureSitePath("/tasks")).toBe("/tasks");
  });

  test("ensureSitePath prepends /s when on Experience path and target lacks /s", () => {
    expect(
      ensureSitePath("project/abc", { currentPathname: "/s/home" })
    ).toBe("/s/project/abc");
    expect(
      ensureSitePath("/project/abc", { currentPathname: "/s/" })
    ).toBe("/s/project/abc");
  });

  test("ensureSitePath does not double /s when already present", () => {
    expect(
      ensureSitePath("/s/tasks", { currentPathname: "/s/home" })
    ).toBe("/s/tasks");
  });

  test("ensureSitePath leaves path unchanged when not on Experience /s context", () => {
    expect(
      ensureSitePath("tasks", { currentPathname: "/lightning/page/home" })
    ).toBe("/tasks");
  });
});
