#!/usr/bin/env perl
use strict;
use warnings;

# Defines the SLA in miliseconds
my $SLA_THRESHOLD_MS = 200;

# This hash (dictionary) maps the priority to normalize the priority levels
my %PRIORITY_MAP = (
    high   => 'P1',
    urgent => 'P1',
    medium => 'P2',
    normal => 'P2',
    low    => 'P3',
    p1     => 'P1',
    p2     => 'P2',
    p3     => 'P3',
);

# This is an array with the tickets to be processed
my @TICKETS = (
    {
        id          => 'TCK-001',
        customer    => 'Acme',
        opened_at   => '2026-01-23T10:05:22Z',
        priority    => 'medium',
        description => 'Intermittent latency spikes reported by monitoring.',
        log_line    => 'status=OK latency_ms=120 region=us-east-1',
    },
    {
        id          => 'TCK-002',
        customer    => 'Globex',
        opened_at   => '2026-01-23T11:18:09Z',
        priority    => 'low',
        description => 'Customer reports slow page loads during peak hours.',
        log_line    => 'status=OK latency_ms=85 region=ap-south-1',
    },
    {
        id          => 'TCK-003',
        customer    => 'Umbra',
        opened_at   => '2026-01-23T12:55:30Z',
        priority    => 'high',
        description => 'Timeouts in EU region with sporadic disconnects.',
        log_line    => 'status=ERROR latency_ms=250 region=eu-west-1 details=connection_timeout=30s',
    },
);

# This function will parse the log line we receive from the tickets
# It will return a reference of the hash
sub parse_log_line {
    my ($log_line) = @_;
    my %data;

    for my $pair (split /\s+/, $log_line) {
        next if $pair eq '';

        #Split the keys and limit to 2 parts to avoid issues whith keys with more than 1 "="
        my ($key, $value) = split /=/, $pair, 2;
        $data{$key} = $value;
    }
    return \%data;
}

# This function will normalize the priority levels to a standard format
sub normalize_priority {
    my ($priority) = @_;
    my $key = lc($priority // '');
    $key =~ s/\s+//g;
    return $PRIORITY_MAP{$key} // 'P3';
}

# This function will parse and extract only the date from opened_at field
sub parse_date {
    my ($opened_at) = @_;
    my ($date) = split /T/, $opened_at;
    return $date;
}

# This function will parse details field and remove the "s" at the end
# Returns the timeout value as an integer
sub parse_timeout_seconds {
    my ($details) = @_;
    my ($key, $value) = split /=/, $details;
    die "Malformed details field: $details" if !defined $value;
    $value =~ s/s$//;
    return $value + 0;
}

# This function will check the priority and if the ticket latency exceeds the SLA thereshold
sub compute_sla_risk {
    my ($priority, $latency_ms) = @_;
    my $is_high = ($priority eq 'P1');
    return ($is_high && $latency_ms > $SLA_THRESHOLD_MS) ? 'yes' : 'no';
}

# This function will process each ticket and extract the information we need to print the output line
sub process_ticket {
    my ($ticket) = @_;

    # Parse log and extract status and region or default to "UNKNOWN"
    my $log = parse_log_line($ticket->{log_line});
    my $status = $log->{status} // 'UNKNOWN';
    my $region = $log->{region} // 'UNKNOWN';

    # Extract latency_ms and turn into a number integer.
    # Will return an error if value is missings or not a number.
    my $latency_ms = $log->{latency_ms};
    die "Missing latency_ms for ticket $ticket->{id}" if !defined $latency_ms;
    $latency_ms = int($latency_ms);

    # Normalize priority and get opened_date
    my $normalized_priority = normalize_priority($ticket->{priority});
    my $opened_date = parse_date($ticket->{opened_at});

    # If there is details fields will be executed otherwise will return an error
    if ($status eq 'ERROR' && exists $log->{details}) {
        my $timeout_s = parse_timeout_seconds($log->{details});
        $ticket->{_timeout_s} = $timeout_s;
    }

    # Compute SLA risk based on priority and latency
    my $sla_risk = compute_sla_risk($normalized_priority, $latency_ms);

    # Builds the output line with the information above
    my $line = sprintf(
        'Ticket %s | customer=%s | date=%s | status=%s | latency_ms=%d | priority=%s | sla_risk=%s',
        $ticket->{id},
        $ticket->{customer},
        $opened_date,
        $status,
        $latency_ms,
        $normalized_priority,
        $sla_risk,
    );

    # Return the line and the extracted information
    return {
        line       => $line,
        latency_ms => $latency_ms,
        status     => $status,
        region     => $region,
    };
}

# Loop to process each ticket, print output, compute totals and find slowest latency ticket
my $processed = 0;
my $ok = 0;
my $failed = 0;
my $latency_sum = 0;
my $slowest;    # { id, latency_ms, region, status }

for my $ticket (@TICKETS) {
    $processed++;
    my $result;
    my $error;

    # Will capture the errors without stopping the execution of the loop
    # If malformed it will return an error message
    eval { $result = process_ticket($ticket); 1 } or do {
        $error = $@ || 'Unknown error';
        chomp $error;
    };

    if ($error) {
        $failed++;
        print "Ticket $ticket->{id} | FAILED | error=$error\n";
        next;
    }

    $ok++;
    $latency_sum += $result->{latency_ms};
    print $result->{line} . "\n";

    if (!$slowest || $result->{latency_ms} > $slowest->{latency_ms}) {
        $slowest = {
            id         => $ticket->{id},
            latency_ms => $result->{latency_ms},
            region     => $result->{region},
            status     => $result->{status},
        };
    }
}

# Print totals and slowest ticket information
my $avg_latency = $ok ? sprintf('%.1f', $latency_sum / $ok) : '0';
print "Totals: processed=$processed ok=$ok failed=$failed avg_latency_ms=$avg_latency\n";

if ($slowest) {
    print "Slowest: ticket=$slowest->{id} region=$slowest->{region} status=$slowest->{status} latency_ms=$slowest->{latency_ms}\n";
}
else {
    print "Slowest: n/a\n";
}

# If there were failed tickets, will exit with an error code and print a message
die "One or more tickets failed (failed=$failed)\n" if $failed;
