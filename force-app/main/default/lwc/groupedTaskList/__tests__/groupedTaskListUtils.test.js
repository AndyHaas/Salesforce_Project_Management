import {
  STANDARD_ACCOUNT_KEY_PREFIX,
  ACCOUNT_SEL_THIS,
  ACCOUNT_SEL_ALL,
  salesforceIdsEqual,
  inferExperienceCloudFromBrowserLocation,
  isExperienceCloudPageReferenceType
} from "../groupedTaskListUtils";

describe("groupedTaskListUtils", () => {
  test("constants", () => {
    expect(STANDARD_ACCOUNT_KEY_PREFIX).toBe("001");
    expect(ACCOUNT_SEL_THIS).toBe("__THIS_ACCOUNT__");
    expect(ACCOUNT_SEL_ALL).toBe("__ALL_ACCOUNTS__");
  });

  test("salesforceIdsEqual", () => {
    expect(salesforceIdsEqual(null, "001xx")).toBe(false);
    expect(salesforceIdsEqual("001000000000000AAA", "001000000000000")).toBe(true);
    expect(salesforceIdsEqual("abc", "def")).toBe(false);
    expect(salesforceIdsEqual(" 001000000000000AAA ", "001000000000000AAA")).toBe(true);
    expect(salesforceIdsEqual("001000000000000", "001000000000000")).toBe(true);
  });

  test("isExperienceCloudPageReferenceType", () => {
    expect(isExperienceCloudPageReferenceType(null)).toBe(false);
    expect(isExperienceCloudPageReferenceType("comm__namedPage")).toBe(true);
    expect(isExperienceCloudPageReferenceType("comm_lwr__home")).toBe(true);
    expect(isExperienceCloudPageReferenceType("lightning__AppPage")).toBe(false);
  });

  test("inferExperienceCloudFromBrowserLocation", () => {
    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "na142.lightning.force.com",
        pathname: "/lightning/page/home"
      })
    ).toBe(false);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "acme.my.site.com",
        pathname: "/s/"
      })
    ).toBe(true);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "custom.example.com",
        pathname: "/s/project/abc"
      })
    ).toBe(true);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "custom.example.com",
        pathname: "/home"
      })
    ).toBe(false);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "",
        pathname: "/about"
      })
    ).toBe(false);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "acme.my.site-preview.com",
        pathname: "/"
      })
    ).toBe(true);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "tenant.live-preview.salesforce.com",
        pathname: "/"
      })
    ).toBe(true);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "acme.my.salesforce.com",
        pathname: "/"
      })
    ).toBe(false);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "custom.na142.force.com",
        pathname: "/s/home"
      })
    ).toBe(true);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "legacy.site.com",
        pathname: "/"
      })
    ).toBe(true);

    expect(
      inferExperienceCloudFromBrowserLocation({
        hostname: "legacy.lightning.site.com",
        pathname: "/"
      })
    ).toBe(false);
  });
});
