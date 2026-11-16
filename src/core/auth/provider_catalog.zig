const std = @import("std");
const model_provider = @import("../config/model_provider.zig");
const types = @import("../shared/types.zig");

pub const Entry = struct {
    id: model_provider.ProviderId,
    slug: []const u8,
    aliases: []const []const u8 = &.{},
    name: []const u8,
    route_name: []const u8,
    description: []const u8,
    subscription: bool,
    login_source: types.CredentialSource,
};

pub const entries = [_]Entry{
    .{
        .id = .gateway,
        .slug = "vercel",
        .aliases = &.{ "gateway", "ai-gateway" },
        .name = "Vercel AI Gateway",
        .route_name = "Vercel AI Gateway",
        .description = "Vercel account or AI Gateway billing",
        .subscription = false,
        .login_source = .fx_login,
    },
    .{
        .id = .codex,
        .slug = "codex",
        .name = "Codex",
        .route_name = "Codex subscription",
        .description = "ChatGPT Plus, Pro, Business, Enterprise, or Edu subscription",
        .subscription = true,
        .login_source = .chatgpt_subscription,
    },
    .{
        .id = .grok,
        .slug = "grok",
        .name = "Grok",
        .route_name = "Grok subscription",
        .description = "SuperGrok or X Premium subscription",
        .subscription = true,
        .login_source = .grok_subscription,
    },
};

pub fn parse(value: []const u8) ?model_provider.ProviderId {
    for (&entries) |*entry| {
        if (std.ascii.eqlIgnoreCase(value, entry.slug)) return entry.id;
        for (entry.aliases) |alias| if (std.ascii.eqlIgnoreCase(value, alias)) return entry.id;
    }
    return null;
}

const configured_entry = Entry{
    .id = model_provider.parse("configured").?,
    .slug = "configured",
    .name = "Configured provider",
    .route_name = "Configured provider",
    .description = "Endpoint and authentication from profile settings",
    .subscription = false,
    .login_source = .configured,
};

pub fn find(id: model_provider.ProviderId) *const Entry {
    if (id == .configured) return &configured_entry;
    for (&entries) |*entry| if (entry.id.eql(id)) return entry;
    unreachable;
}

pub fn label(id: model_provider.ProviderId) []const u8 {
    return find(id).route_name;
}

/// A provider's name for messages: a configured connection's own name, borrowed
/// from the caller's value, or the catalog's route name for a factory one. The
/// pointer keeps the borrowed name from pointing at a copy that dies with the
/// call, which is what a by-value parameter would return.
///
/// Fork: the profile's own connections are the only providers this build
/// offers, so every notice names the connection instead of "Configured
/// provider".
pub fn displayName(id: *const model_provider.ProviderId) []const u8 {
    return if (id.* == .configured) id.label() else find(id.*).route_name;
}

test "display name names a configured connection" {
    var configured = model_provider.parse("unlid").?;
    try std.testing.expectEqualStrings("unlid", displayName(&configured));
    var factory: model_provider.ProviderId = .gateway;
    try std.testing.expectEqualStrings("Vercel AI Gateway", displayName(&factory));
}

test "auth provider catalog uses the model provider identity and explicit aliases" {
    try std.testing.expectEqual(model_provider.ProviderId.gateway, parse("vercel").?);
    try std.testing.expectEqual(model_provider.ProviderId.gateway, parse("gateway").?);
    try std.testing.expectEqual(model_provider.ProviderId.codex, parse("codex").?);
    try std.testing.expectEqual(model_provider.ProviderId.grok, parse("grok").?);
    try std.testing.expect(parse("openai-codex") == null);
    try std.testing.expect(parse("chatgpt") == null);
    try std.testing.expect(parse("unknown") == null);
    try std.testing.expect(find(.codex).subscription);
    try std.testing.expect(find(.grok).subscription);
}
