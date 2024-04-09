dashboard "aws_identity_center_dashboard" {

  title = "AWS Identity Center (SSO)"

  tags = {
    type = "Report"
    service = "SSO"
  }

  input "identity_store" {
    title = "Identity Store"
    type  = "select"
    width = 2

    sql  = <<-EOQ
        select
        identity_store_id as label,
        identity_store_id as value
        from
        aws_ssoadmin_instance;
    EOQ
    }

  input "fake_input"{
    title = "Fake"
    type = "select"
    width = 2
    sql = <<-EOQ
          CREATE OR REPLACE FUNCTION get_account_assignments(IN aws_group_principal_id varchar)
            RETURNS TABLE(account_id TEXT, permission_set_arn TEXT) AS $$
            DECLARE
            combination record;
            BEGIN
            FOR combination in
                SELECT a.id AS account_id, ps.arn AS permission_set_arn
                FROM aws_organizations_account AS a
                CROSS JOIN aws_ssoadmin_permission_set AS ps

            LOOP

                -- Check if an assignment exists for the current combination
                IF EXISTS (SELECT 1 FROM aws_ssoadmin_account_assignment AS aa
                        WHERE aa.target_account_id = combination.account_id
                        AND aa.permission_set_arn = combination.permission_set_arn
                        AND aa.principal_id = aws_group_principal_id) THEN
                account_id := combination.account_id;
                permission_set_arn := combination.permission_set_arn;
                RETURN NEXT;

                END IF;
            END LOOP;
            END;
            $$ LANGUAGE plpgsql;
            EOQ
  }

  input "identity_store_group" {
    title = "Group"
    type  = "select"
    width = 2

    sql  = <<-EOQ
        select
        name as label,
        id as value
        from
        aws_identitystore_group
        WHERE 
        identity_store_id = $1 ;
    EOQ

            args = [self.input.identity_store]

    }


    graph {
        title = "AWS SSO Permissions"

        node {
        category = category.group
        sql = <<-EOQ
                select
                id as id,
                name as title
                from
                aws_identitystore_group
                where
                id = $1 and
                identity_store_id = $2
            EOQ

            args = [self.input.identity_store_group, self.input.identity_store ]
        }


        node {
            category = category.account

            sql = <<-EOQ

            select get_account_assignments.account_id as id, 
            aws_organizations_account.name as title 
            from get_account_assignments( $1 )
            LEFT JOIN  aws_organizations_account on  
            aws_organizations_account.id = get_account_assignments.account_id ;

            EOQ

            args = [self.input.identity_store_group]

        }

        edge {

            sql = <<-EOQ

            select $1 as from_id,
            account_id as to_id 
            from get_account_assignments( $1 );

            EOQ

            args = [self.input.identity_store_group]


        }

        node {
            category = category.permissionset

            sql = <<-EOQ

            select get_account_assignments.account_id || get_account_assignments.permission_set_arn as id, 
            aws_ssoadmin_permission_set.name as title 
            from get_account_assignments( $1 )
            LEFT JOIN  aws_ssoadmin_permission_set on  
            aws_ssoadmin_permission_set.arn= get_account_assignments.permission_set_arn ;;

            EOQ

            args = [self.input.identity_store_group]

        }

        edge {

            sql = <<-EOQ

            SELECT
            account_id as from_id,
            account_id || permission_set_arn as to_id
            from get_account_assignments( $1 );

            EOQ

            args = [self.input.identity_store_group]

        }



    }

    table {
        title = "Members -- Note, deactivated members may be shown but not noted as deactivated in this view."

        sql   = <<-EOQ
            select
                aws_identitystore_user.name as Name
            from
                aws_identitystore_group_membership
            LEFT JOIN 
                aws_identitystore_user ON aws_identitystore_user.id = aws_identitystore_group_membership.member_id
            where
                aws_identitystore_group_membership.identity_store_id = $2
            AND
                aws_identitystore_user.identity_store_id = $2
            AND
                aws_identitystore_group_membership.group_id = $1


        EOQ

        args = [self.input.identity_store_group, self.input.identity_store ]

    }




}



category "group" {
  title = "Group"
  color = "grey"
  icon  = "https://d2908q01vomqb2.cloudfront.net/22d200f8670dbdb3e253a90eee5098477c95c23d/2021/06/30/AWS-Single-Sign-On-ForSocial.jpg"
}

category "account" {
  title = "Account"
  color = "white"
  icon  = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/AWS_Simple_Icons_AWS_Cloud.svg/2560px-AWS_Simple_Icons_AWS_Cloud.svg.png"
}

category "permissionset" {
  title = "PermissionSet"
  color = "white"
  icon  = "key"
}