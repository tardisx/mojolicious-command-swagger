use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Generate swagger JSON from REST documenation",
  "AUTHOR" => "Justin Hawkins",
  "DISTNAME" => "Mojolicious-Command-swagger",
  "LICENSE" => "perl",
  "NAME" => "Mojolicious::Command::swagger",
  "PREREQ_PM" => {
    "Mojolicious" => "4.43"
  },
  "VERSION" => "0.01",
  "test" => {
    "TESTS" => "t/*.t"
  }
);

WriteMakefile(%WriteMakefileArgs);



