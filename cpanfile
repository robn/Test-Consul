requires 'Moo' => 1.006000;
requires 'strictures' => 2.000000;
requires 'namespace::clean' => 0;
requires 'Test::Simple' => 0.94;
requires 'Test::TCP' => 2.17;
requires 'IPC::Cmd' => 0;
requires 'Capture::Tiny' => 0.31;
requires 'Carp' => 0;
requires 'Log::Any' => 0.11;
requires 'Time::HiRes' => 0;
requires 'JSON::MaybeXS' => 1.003007;
requires 'File::Temp' => 0;

on test => sub {
    requires 'Test2::Bundle::Extended' => '0.000058';
    requires 'Log::Any::Adapter::TAP' => 0.2.0;
};
