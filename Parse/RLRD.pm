use strict;
use warnings;

package Parse::RLRD::Base;

use base 'Class::Data::Accessor';

sub new {
    my $class = shift;
    my $self = bless {}, ref $class || $class;

    my $args = ref $_[0] ? {%{$_[0]}} : {@_};
    while (my ($k, $v) = each %$args) {
        $self->can($k) ? $self->$k($v) : ($self->{$k} = $v);
    }
    return $self;
}

package Parse::RLRD::Rule;

use Scalar::Util 'blessed';

use base 'Parse::RLRD::Base';

__PACKAGE__->mk_classaccessor('rule_class', __PACKAGE__);
__PACKAGE__->mk_classaccessor('fallback_class', __PACKAGE__ . '::Fallback');
__PACKAGE__->mk_classaccessor('node_class', (__PACKAGE__ =~ /(.*)::/)[0] . '::Node');

sub build {
    my ($self, $node, $matches, $options) = @_;
    $options ||= {};
    
    my $target;
    if (defined $self->{tag}) {
        $target = $self->node_class->new($self->{tag});
        $node->append($target);
    }
    else {
        $target = $node;
    }
    
    if (defined $self->{capture}) {
        my $data = $matches->[$self->{capture}][0];
        $data =~ s/$self->{replace_regex}/$self->{replace_string}/g
            if $self->{replace_regex};
        $self->apply($target, $data, $options);
    }
    
    return $node;
}

sub match {
    my ($self, $data) = @_;
    $data =~ $self->{regex} or return;
    no strict 'refs';
    return [ map { [ $_ ? $$_ : substr($data, $-[$_], $+[$_] - $-[$_]), $-[$_] ] } 0 .. $#- ];
}

sub apply {
    my ($self, $node, $data, $options) = @_;
    $options ||= {};
    
    my $tail = $data;
    
    if (!blessed($self->{fallback})) {
        $self->{fallback} = $self->{fallback}
            ? $self->rule_class->new($self->{fallback})
            : $self->fallback_class->new;
    }
#use Data::Dumper;
    
    my $matches;
    while (1) {
        my ($best, $rule);
        
        for (my $i = 0; $i < @{$self->{children} || []}; $i++) {
            if (!$matches->[$i]) {
                $self->{children}[$i] = $self->rule_class->new($self->{children}[$i])
                    if !blessed($self->{children}[$i]);
                $matches->[$i] = $self->{children}[$i]->match($tail);
#print Dumper([$tail, $self->{children}[$i] ]);
#print $matches->[$i] ? "matched\n" : "didn't match\n";
            }
            
            if ($matches->[$i] && (!$best || $matches->[$i][0][1] < $best->[0][1])) {
                $best = $matches->[$i]; # XXX
#print Dumper($best);
                $rule = $self->{children}[$i];
                last if $best->[0][1] == 0;
            }
        }
        
#print Dumper { best => $best, tail => $tail, matches => $matches };

        my $pos = $best ? $best->[0][1] : length($tail);
        $self->{fallback}->apply($node, substr($tail, 0, $pos), $options)
            if $pos > 0;
        
        $best or last;
        
        $rule->build($node, $best, $options);
        
        my $chopped = $best->[0][1] + length($best->[0][0]);
        last if $chopped >= length($tail); # XXX        
        $tail = substr($tail, $chopped);
        
        for (my $i = 0; $i < @{$self->{children}}; $i++) {
            next if !$matches->[$i];
            if ($matches->[$i][0][1] >= $chopped) {
                $matches->[$i][0][1] -= $chopped;
            }
            else {
                undef $matches->[$i];
            }
        }
#print Dumper { matches => $matches };
    }
    
    return $node;
}

package Parse::RLRD::Rule::Fallback;

use base 'Parse::RLRD::Rule';

sub apply {
    my ($self, $node, $data, $options) = @_;
    $node->append($data);
}

package Parse::RLRD::Node;

use Scalar::Util 'blessed';

use base 'Parse::RLRD::Base';

sub new {
    my $self = shift;
    $self->SUPER::new(@_ == 1 && !ref $_[0] ? { tag => $_[0] } : @_);
}

sub append { push @{$_[0]->{content}}, $_[1]; }

sub as_struct {
    my ($self) = @_;
    
    my $content = [ map { blessed($_) ? $_->as_struct : $_ } @{$self->{content} || []} ];
    return $self->{tag} && $self->{tag} gt '' ? { $self->{tag} => $content } : $content;
}

1;
