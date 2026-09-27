use MCP::Server;
use MCP::Server::Toolkit;

unit class Metamodel::McpHOW is Metamodel::ClassHOW;

has &.build-server;
has @.mcp-registrars;

class MCP::Base does MCP::Server::Toolkit {
	# Private and lazy: the server is built on first use, and keeping it out of
	# the public attribute list means .from-config never mistakes it for a
	# configurable setting.
	has MCP::Server $!server;

	method server(--> MCP::Server) {
		$!server //= self.HOW.build-server.(self);
	}

	#| MCP::Server::Toolkit: register this instance's methods as tools on any
	#| server, so an mcp class can be plugged into a bigger server too.
	method register($registrar) {
		for self.HOW.mcp-registrars -> &reg { reg $registrar, :obj(self) }
	}

	method run(|c)                { self.server.run: |c }
	method tools-for-llm(|c)      { self.server.tools-for-llm: |c }
	method execute-tool-calls(|c) { self.server.execute-tool-calls: |c }
	method handle-request(|c)     { self.server.handle-request: |c }
}

my %type-map = %(
	Any         => "string",
	Str         => "string",
	Int         => "integer",
	Bool        => "boolean",
	Num         => "number",
	Rat         => "number",
	Positional  => "array",
	Associative => "object",
);

multi type-map(Parameter $_ where *.?mcp-type) {
	.mcp-type
}

multi type-map(Parameter $par) {
	CATCH {
		default {
			die "Type `{$par.type.^name}` for `{$par.gist}` can not be auto converted to json type. Please, use `is mcp-type` for that type."
		}
	}
	type-map $par.type
}

multi type-map(Mu $_ where { .HOW ~~ Metamodel::CoercionHOW }) {
	type-map .^constraint_type
}

multi type-map(Mu $_ where { %type-map{.^name}:!exists }) {
	die "Type {.^name} can not be auto converted to json type. Please, use `is mcp-type` for that type."
}

multi type-map(Mu $_) {
	%type-map{.^name}
}

method compose(Mu $_) {
	.^add_parent: MCP::Base;

	callsame;

	my \type = $_;

	my @tools = do for .^methods: :local -> &method {
		my $name  = &method.name;
		next if $name eq "POPULATE";
		# Validate and type-map eagerly (compile-time errors stay compile-time);
		# keep the Parameter objects so .WHY is read lazily, at runtime.
		my @params = &method.signature.params.skip.map: {
			next if .name eq '%_';
			die "MCP::Server::DSL does not accept slurp parameters ({&method.name} -> {.gist})." if .slurpy;
			die "MCP::Server::DSL does not accept positional parameters ({&method.name} -> {.gist})." unless .named;
			($_, .named_names.head, type-map($_))
		}

		-> $_, :$obj! {
			my %params := Map.new: @params.map: -> ($p, $pname, $type) {
				$pname => %(
					type          => $type,
					required      => !$p.optional,
					|(description => ~$p.WHY if $p.WHY),
				)
			}
			.tool: $name,
			|(:description(.Str) with &method.WHY),
			:%params,
			:handler(-> :%args { $obj.&method(|%args) })
		}
	}

	@!mcp-registrars = @tools;

	&!build-server = -> $obj {
		my $server = MCP::Server.new:
			name           => type.^name,
			|(version      => ~type.^ver if type.^ver),
			|(instructions => ~type.WHY  if type.WHY );
		for @!mcp-registrars -> &tool { tool $server, :$obj }
		$server
	}
}
