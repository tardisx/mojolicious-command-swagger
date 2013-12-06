package Mojolicious::Command::swagger;

use Mojo::Base 'Mojolicious::Command';

use Pod::POM;

has description => "Export Swagger JSON.\n";

has usage => <<EOF;
usage: $0 swagger [OPTIONS]

These options are available:

EOF

my $parser = Pod::POM->new;
my $namespaces = [];

sub run {
  my ($self, @args) = @_;

  $namespaces = $self->app->routes->namespaces;

  # warn Dumper $self->app->routes->children;
  foreach my $route (@{ $self->app->routes->children }) {
    process_route($route);
  }

}

sub process_route {
  my $route = shift;
  my $name   = $route->name;
  my $method = $route->via || 'ANY';
  $method    = join('/', @$method) if (ref $method);

  my $controller = $route->to->{controller} || 'unknown';
  my $action     = $route->to->{action}     || 'unknown';

  say "$name / $method => $controller->$action";
  process_module_method($controller, $action);

  if ($route->children) {
    process_route($_) foreach (@{ $route->children});
  }
}

sub process_module_method {
  my ($module, $method) = @_;

  NS: foreach my $ns (@$namespaces) {
    my $this_module = "${ns}::$module";

    my $path = $this_module;
    $path =~ s/::/\//g;  # unix specific
    $path .= ".pm";

    eval "require $this_module " or do { next; };
    next unless ($INC{$path});

    my $pom = $parser->parse_file($INC{$path});
    foreach my $head2 ($pom->head2()) {
      next unless ($head2->title eq $method);
      say "METHOD: ". $head2->title;
      say "DOC: "   . $head2->content;
      last NS;
    }
  }
}

1;
