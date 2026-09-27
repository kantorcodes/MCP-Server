use MCP::Server::Toolkit;

# Test fixture: a toolkit with only optional settings that registers one of
# everything (tool, prompt, resource) so prefixing can be checked end to end.
unit class MCP::Server::Tool::TestKit does MCP::Server::Toolkit;

has Str $.greeting = 'Hello';
has IO::Path() $.root = '.'.IO;

method register($registrar) {
	$registrar.tool: 'greet',
		description => 'Greet somebody by name',
		params => {
			name => { type => 'string', description => 'Who to greet', required => True },
		},
		handler => -> :%args { "{$!greeting}, {%args<name>}" };

	$registrar.prompt: 'greeting',
		description => 'A greeting prompt',
		arguments => [
			{ name => 'name', description => 'Who to greet', required => True },
		],
		handler => -> :%args { "{$!greeting}, {%args<name> // 'world'}!" };

	$registrar.resource: 'test://info',
		name => 'TestKit info',
		description => 'Information about this kit',
		mime-type => 'text/plain',
		handler => -> :%args { "greeting={$!greeting} root={$!root}" };
}

=begin pod

=head1 NAME

MCP::Server::Tool::TestKit - a fixture toolkit with one of everything

=head1 DESCRIPTION

This — and its sibling C<MCP::Server::Tool::StrictKit> — is test support,
not library surface. It ships inside the dist's own namespace (rather than
under C<t/lib>) deliberately, so that C<zef install>'s test phase
precompiles it as part of C<lib/> staging before any test file runs. A
C<t/lib> CompUnit repo starts cold on a fresh C<zef install>, and parallel
test files pulling the fixtures' dependency chain into that cold store can
race and fail the install outright; moving test support into the dist's
own namespace is the fleet-wide fix for that failure class.

=end pod
