import EmptyState from '../components/common/EmptyState';
import PageContainer from '../components/layout/PageContainer';

export default function PlaceholderPage({ icon: Icon, title, description }) {
  return (
    <PageContainer>
      <EmptyState icon={Icon} title={title} description={description} />
    </PageContainer>
  );
}
