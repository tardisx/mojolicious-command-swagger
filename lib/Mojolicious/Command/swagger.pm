package Mojolicious::Command::swagger;

use Mojo::Base 'Mojolicious::Command';

use Mojo::JSON;

use Pod::POM;

use Getopt::Long qw/GetOptionsFromArray/;

has description => "Export Swagger JSON.\n";

has usage => <<EOF;
usage: $0 swagger [OPTIONS]

These options are available:

EOF

my $parser = Pod::POM->new;
my $metadata   = {};
my $path_descriptions = {};
my $routedata  = {};
my $namespaces = [];

sub run {
  my ($self, @args) = @_;

  my $verbose = 0;

  GetOptionsFromArray(\@args, "verbose" => \$verbose );

  $namespaces = $self->app->routes->namespaces;


  foreach my $route (@{ $self->app->routes->children }) {
    process_route($route);
  }

  use Data::Dumper;

  my $output = { apiVersion => '0.2', swaggerVersion => '1.2', basePath => 'http://localhost:3000', resourcePath => '', apis => [] };

  foreach my $path (keys $routedata) {
      my $new_path = { path => $path, description => $path_descriptions->{$path}, operations => []};
      foreach my $method ( keys %{ $routedata->{$path} } ) {
          push @{ $new_path->{operations} },  $routedata->{$path}->{$method};
      }
      push @{ $output->{apis} }, $new_path;
  }

  warn Dumper $output;
  say Mojo::JSON->new->encode($output);

}

sub process_route {
  my $route = shift;
  my $pattern = shift || '';
  my $name   = $route->name;
  my $method = $route->via || 'ANY'; # XXX we should probably reject ANY, bad RESTfulness!
  $method    = [ $method ] unless (ref $method);

  my $controller = $route->to->{controller};
  my $action     = $route->to->{action};
  $pattern   .= $route->pattern->pattern || '';

  #say "";
  #say "-" x 72;

  if ($controller && $action) {

#      say "$name / $method => $controller->$action";
#      say "PATTERN: $pattern";
      foreach my $via (@$method) {
          process_module_method($controller, $action, $pattern, $via);
      }
  }

  if ($route->children) {
    process_route($_, $pattern) foreach (@{ $route->children});
  }
}

sub process_module_method {
  my ($module, $method, $pattern, $via) = @_;

  NS: foreach my $ns (@$namespaces) {
    my $this_module = "${ns}::$module";

    my $path = $this_module;
    $path =~ s/::/\//g;
    $path .= ".pm";

    eval "require $this_module " or do { next; };
    next unless ($INC{$path});

    # parse this module
    my $pom = $parser->parse_file($INC{$path});

    # look for the method in this module in the pod =head2
    my $path_description;
    foreach my $head1 ($pom->head1) {
        $path_descriptions->{$pattern} = "" . $head1->title;
        foreach my $head2 ($head1->head2()) {
            next unless ($head2->title =~ /^$method\s+\-\s+(.*)$/);
            my $summary = $1;
            my $notes   = "" . $head2->text();

            $routedata->{$pattern}->{$via}->{type}     = 'void';
            $routedata->{$pattern}->{$via}->{summary}  = $summary;
            $routedata->{$pattern}->{$via}->{notes}    = pod2html($notes);
            $routedata->{$pattern}->{$via}->{method}   = $via;
            $routedata->{$pattern}->{$via}->{nickname} = "${via}_$method";

            # parameters
            $routedata->{$pattern}->{$via}->{parameters} = [];

            return;
        }
    }
  }
}

sub pod2html {
    my $pod = shift;
    my $html;

    $html = $pod;

    # unfortunately swagger-ui seems to eat this formatting in the notes field
    $html =~ s/C<(.+?)>/<tt>$1<\/tt>/gms;

    $html =~ s/\n\n/<br><br>/gms;

    return $html;
}



1;
