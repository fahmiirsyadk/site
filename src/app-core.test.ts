import { describe, expect, test } from "vitest";

import {
  commandTags,
} from "purescript/App.Wire.Command/index.ts";
import { isKnownTag as isKnownMessageTag, messageTags } from "purescript/App.Wire.Message/index.ts";
import { initInput, routeMotionName, updateInput } from "purescript/App.Update/index.ts";
import type { RawMessage } from "purescript/App.Wire.Message/index.ts";
import { routePath } from "purescript/App.Route/index.ts";

const rawMessage = (fields: Partial<RawMessage>): RawMessage => ({
  _tag: "Unknown",
  requestTag: "",
  requestUrl: "",
  requestHref: "",
  url: "",
  theme: "",
  contributions: 0,
  followers: 0,
  levels: [],
  ...fields,
});

describe("PureScript application core", () => {
  test("owns runtime message-tag recognition", () => {
    expect(isKnownMessageTag("ChangedUrl")).toBe(true);
    expect(isKnownMessageTag("ClickedLink")).toBe(true);
    expect(isKnownMessageTag("AccidentallyAddedMessage")).toBe(false);
    expect(messageTags).toHaveLength(23);
    expect(new Set(messageTags).size).toBe(messageTags.length);
    expect(commandTags).toStrictEqual([
      "NavigateInternal",
      "LoadExternal",
      "StartRouteEntry",
      "LoadGitHub",
      "CopyPostLink",
      "ResetCopyStatus",
      "ReadTheme",
      "PersistTheme",
      "ResetScroll",
      "SyncDocumentMetadata",
    ]);
  });

  test("initializes the route model and command specs in PureScript", () => {
    const initialized = initInput({ path: "/thought/" });

    expect(routePath(initialized.model.route)).toBe("/thought/");
    expect(initialized.commands.map((command) => command._tag)).toStrictEqual([
      "ReadTheme",
      "LoadGitHub",
      "SyncDocumentMetadata",
    ]);
    expect(initialized.commands.at(-1)).toMatchObject({
      _tag: "SyncDocumentMetadata",
      title: "Faah",
      contentType: "website",
    });
  });

  test("updates route state and emits command specs in PureScript", () => {
    const initialized = initInput({ path: "/" });
    const updated = updateInput({
      model: initialized.model,
      message: rawMessage({
        _tag: "ChangedUrl",
        url: "/lab/",
      }),
    });

    expect(routePath(updated.model.route)).toBe("/lab/");
    expect(routeMotionName(updated.model)).toBe("entering");
    expect(updated.commands.map((command) => command._tag)).toStrictEqual([
      "StartRouteEntry",
      "ResetScroll",
      "SyncDocumentMetadata",
    ]);
    expect(updated.commands.at(-1)).toMatchObject({
      _tag: "SyncDocumentMetadata",
      title: "Faah",
      contentType: "website",
    });
  });

  test("recovers route motion when internal navigation fails", () => {
    const initialized = initInput({ path: "/" });
    const leaving = updateInput({
      model: initialized.model,
      message: rawMessage({
        _tag: "ClickedLink",
        requestTag: "Internal",
        requestUrl: "/thought/",
      }),
    });
    const recovered = updateInput({
      model: leaving.model,
      message: rawMessage({ _tag: "FailedNavigateInternal" }),
    });

    expect(routeMotionName(leaving.model)).toBe("leaving");
    expect(routeMotionName(recovered.model)).toBe("idle");
  });

  test("delegates Home and Post state transitions to their page updates", () => {
    const initialized = initInput({ path: "/" });
    const loadedHome = updateInput({
      model: initialized.model,
      message: rawMessage({
        _tag: "SucceededLoadGitHub",
        contributions: 12,
        followers: 3,
        levels: [1, 2, 3],
      }),
    });

    expect(loadedHome.model.home.status.constructor.name).toBe("Ready");

    const hoveredLab = updateInput({
      model: loadedHome.model,
      message: rawMessage({ _tag: "HoveredLab" }),
    });

    expect(hoveredLab.model.home.labInteraction.constructor.name).toBe(
      "LabHovered",
    );

    const leftLab = updateInput({
      model: hoveredLab.model,
      message: rawMessage({ _tag: "LeftLab" }),
    });

    expect(leftLab.model.home.labInteraction.constructor.name).toBe("LabIdle");

    const requestedCopy = updateInput({
      model: leftLab.model,
      message: rawMessage({ _tag: "ClickedCopyPostLink", url: "/thought/example/" }),
    });

    expect(requestedCopy.commands.map((command) => command._tag)).toStrictEqual(
      ["CopyPostLink"],
    );

    const copiedPost = updateInput({
      model: requestedCopy.model,
      message: rawMessage({ _tag: "SucceededCopyPostLink" }),
    });

    expect(copiedPost.model.post.copyStatus.constructor.name).toBe("Copied");
    expect(copiedPost.commands.map((command) => command._tag)).toStrictEqual([
      "ResetCopyStatus",
    ]);
  });
});
